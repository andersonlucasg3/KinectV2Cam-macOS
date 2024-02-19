#import "KV2VirtualCamDeviceSource.h"
#import "KV2VirtualCamStreamSource.h"
#import "KV2VirtualCamConstants.h"
#import "KV2VirtualCamLogging.h"

#import <IOKit/audio/IOAudioTypes.h>
#import <os/log.h>

@implementation KV2VirtualCamDeviceSource

+ (instancetype)deviceWithLocalizedName:(NSString *)localizedName deviceSerialNumber:(NSString*)deviceSN libKinect:(KV2VirtualCamLibKinect *)libKinect
{
    return [[[self class] alloc] initWithLocalizedName:localizedName deviceSerialNumber:deviceSN libKinect:libKinect];
}

- (instancetype)initWithLocalizedName:(NSString *)localizedName deviceSerialNumber:(NSString*)deviceSN libKinect:(KV2VirtualCamLibKinect *)libKinect
{
    self = [super init];
    if (self) {
        _libKinect = libKinect;
        _kinectDevice = [_libKinect openKinectDevice:deviceSN];
        
        NSString* kinectV2UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:@"KinectV2UUID"];
        NSUUID *deviceID = kinectV2UUIDString != nil ? [[NSUUID alloc] initWithUUIDString:kinectV2UUIDString] : [NSUUID UUID];
        if (kinectV2UUIDString == nil)
        {
            [[NSUserDefaults standardUserDefaults] setObject:[deviceID UUIDString] forKey:@"KinectV2UUID"];
        }
        _device = [[CMIOExtensionDevice alloc] initWithLocalizedName:localizedName deviceID:deviceID legacyDeviceID:nil source:self];
        
        _timerQueue = dispatch_queue_create_with_target("timerQueue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
        
        CMVideoDimensions dims = {.width = 1920, .height = 1080};
        (void)CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCVPixelFormatType_32BGRA, dims.width, dims.height, NULL, &_videoDescription);
        if (_videoDescription) 
        {
            NSDictionary *pixelBufferAttributes = @{ (id)kCVPixelBufferWidthKey : @(dims.width),
                                                     (id)kCVPixelBufferHeightKey : @(dims.height),
                                                     (id)kCVPixelBufferPixelFormatTypeKey : @(CMFormatDescriptionGetMediaSubType(_videoDescription)),
                                                     (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                                    };
            (void)CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)pixelBufferAttributes, &_bufferPool);
        }
                
        CMIOExtensionStreamFormat *videoStreamFormat = nil;
        if (_bufferPool) 
        {
            videoStreamFormat = [[CMIOExtensionStreamFormat alloc] initWithFormatDescription:_videoDescription maxFrameDuration:CMTimeMake(1, kFrameRate) minFrameDuration:CMTimeMake(1, kFrameRate) validFrameDurations:nil];
            _bufferAuxAttributes = @{(id)kCVPixelBufferPoolAllocationThresholdKey : @(5)};
        }
        
        if (videoStreamFormat) 
        {
            NSUUID *videoID = [[NSUUID alloc] init]; // replace this with your video UUID
            _streamSource = [[KV2VirtualCamStreamSource alloc] initWithLocalizedName:@"SampleCapture.Video" streamID:videoID streamFormat:videoStreamFormat device:_device];
            
            NSError *error = nil;
            if (![_device addStream:_streamSource.stream error:&error]) 
            {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Failed to add stream: %@", error.localizedDescription] userInfo:nil];
            }
        }
    }
    
    return self;
}

- (void) dealloc
{
    [_libKinect closeKinectDevice:_kinectDevice];
}

- (NSSet<CMIOExtensionProperty> *)availableProperties
{
    return [NSSet setWithObjects:CMIOExtensionPropertyDeviceTransportType, CMIOExtensionPropertyDeviceModel, nil];
}

- (nullable CMIOExtensionDeviceProperties *)devicePropertiesForProperties:(NSSet<CMIOExtensionProperty> *)properties error:(NSError * _Nullable *)outError
{
    CMIOExtensionDeviceProperties *deviceProperties = [CMIOExtensionDeviceProperties devicePropertiesWithDictionary:@{}];
    if ([properties containsObject:CMIOExtensionPropertyDeviceTransportType]) {
        deviceProperties.transportType = [NSNumber numberWithInt:kIOAudioDeviceTransportTypeVirtual];
    }
    if ([properties containsObject:CMIOExtensionPropertyDeviceModel]) {
        deviceProperties.model = @"KinectV2";
    }
    
    return deviceProperties;
}

- (BOOL)setDeviceProperties:(CMIOExtensionDeviceProperties *)deviceProperties error:(NSError * _Nullable *)outError
{
    // Handle settable properties here.
    return YES;
}

- (void)startStreaming
{
    if (!_bufferPool) return;
    
    if (_streamingCounter == 0)
    {
        if (![_libKinect startStreamingDevice:_kinectDevice]) return;
    }
    
    _streamingCounter++;
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, _timerQueue);
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, (uint64_t)(NSEC_PER_SEC/kFrameRate), 0);
    
    dispatch_source_set_event_handler(_timer, ^
    {
        OSStatus err = noErr;
        CMTime now = CMClockGetTime(CMClockGetHostTimeClock());
        
        CVPixelBufferRef pixelBuffer = NULL;
        err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self.bufferPool, (__bridge CFDictionaryRef)self.bufferAuxAttributes, &pixelBuffer );
        if (err) 
        {
            os_log(KV2VirtualCamLog, "out of pixel buffers %d", err);
        }
        
        if (pixelBuffer) {
            
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            {
                uint8_t *bufferPtr = static_cast<uint8_t*>(CVPixelBufferGetBaseAddress(pixelBuffer));
                
                [self->_libKinect waitForFrame:self->_kinectDevice processFrame:^(size_t width, size_t height, uint8 bytesPerPixel, unsigned char *frame)
                {
                    memcpy(bufferPtr, frame, width * height * bytesPerPixel);
                }];
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            
            CMSampleBufferRef sbuf = NULL;
            CMSampleTimingInfo timingInfo;
            timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock());
            err = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, self.videoDescription, &timingInfo, &sbuf);
            CFRelease(pixelBuffer);
            if (!err) 
            {
                [self->_streamSource.stream sendSampleBuffer:sbuf discontinuity:CMIOExtensionStreamDiscontinuityFlagNone hostTimeInNanoseconds:(uint64_t)(CMTimeGetSeconds(timingInfo.presentationTimeStamp) * NSEC_PER_SEC)];
                CFRelease(sbuf);
            }
            os_log(KV2VirtualCamLog, "video time %.3f now %.3f err %d", CMTimeGetSeconds(timingInfo.presentationTimeStamp), CMTimeGetSeconds(now), (int)err);
        }
    });
    
    dispatch_source_set_cancel_handler(_timer, ^{
    });
    
    dispatch_resume(_timer);
}

- (void)stopStreaming
{
    if (_streamingCounter > 1) 
    {
        _streamingCounter -= 1;
    }
    else
    {
        [_libKinect stopStreamingDevice:_kinectDevice];
        
        _streamingCounter = 0;
        
        if (_timer) {
            dispatch_source_cancel(_timer);
            _timer = nil;
        }
    }
}

@end
