#import "KV2VirtualCamDeviceSource.h"
#import "KV2VirtualCamStreamSource.h"
#import "KV2VirtualCamConstants.h"
#import "KV2VirtualCamLogging.h"

#import <IOKit/audio/IOAudioTypes.h>
#import <os/log.h>

@interface KV2VirtualCamDeviceSource ()

- (uint32_t) getStreamingCounter;
- (void) zeroStreamingCounter;
- (void) increaseStreamingCounter;
- (void) decreaseStreamingCounter;

@end

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
            videoStreamFormat = [[CMIOExtensionStreamFormat alloc] initWithFormatDescription:_videoDescription maxFrameDuration:CMTimeMake(1, kFramesPerSecond) minFrameDuration:CMTimeMake(1, kFramesPerSecond) validFrameDurations:nil];
            _bufferAuxAttributes = @{(id)kCVPixelBufferPoolAllocationThresholdKey : @(5)};
        }
        
        if (videoStreamFormat) 
        {
            NSUUID *videoID = [[NSUUID alloc] init]; // replace this with your video UUID
            _streamSource = [[KV2VirtualCamStreamSource alloc] initWithLocalizedName:@"KinectV2.Video" streamID:videoID streamFormat:videoStreamFormat device:_device];
            
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
    
    [self zeroStreamingCounter];
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
    
    if ([self getStreamingCounter] == 0)
    {
        if (![_libKinect startStreamingDevice:_kinectDevice]) return;
    }
    
    [self increaseStreamingCounter];
    
    [NSThread detachNewThreadWithBlock:^
    {
        BOOL isStreaming = true;
        do
        {
            [self->_libKinect waitForFrame:self->_kinectDevice processFrame:^(size_t width, size_t height, uint8 bytesPerPixel, unsigned char *frame)
            {
                OSStatus err = noErr;
                CMTime now = CMClockGetTime(CMClockGetHostTimeClock());
                
                CVPixelBufferRef pixelBuffer = NULL;
                err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self.bufferPool, (__bridge CFDictionaryRef)self.bufferAuxAttributes, &pixelBuffer );
                
#if DEBUG
                if (err)
                {
                    os_log(KV2VirtualCamLog, "out of pixel buffers %d", err);
                }
#endif
                
                if (pixelBuffer)
                {
                    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                    {
                        uint8_t *bufferPtr = static_cast<uint8_t*>(CVPixelBufferGetBaseAddress(pixelBuffer));
                        
                        memcpy(bufferPtr, frame, width * height * bytesPerPixel);
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
                    
#if DEBUG
                    os_log(KV2VirtualCamLog, "video time %.3f now %.3f err %d", CMTimeGetSeconds(timingInfo.presentationTimeStamp), CMTimeGetSeconds(now), (int)err);
#endif
                }
            }];
            
            isStreaming = [self getStreamingCounter] > 0;
        }
        while (isStreaming);
    }];
}

- (void)stopStreaming
{
    if ([self getStreamingCounter] > 1)
    {
        [self decreaseStreamingCounter];
    }
    else
    {
        [_libKinect stopStreamingDevice:_kinectDevice];
        
        [self zeroStreamingCounter];
    }
}

- (uint32_t)getStreamingCounter
{
    @synchronized (self)
    {
        return _streamingCounter;
    }
}

- (void)zeroStreamingCounter
{
    @synchronized (self)
    {
        _streamingCounter = 0;
    }
}

- (void)increaseStreamingCounter
{
    @synchronized (self)
    {
        _streamingCounter += 1;
    }
}

- (void)decreaseStreamingCounter
{
    @synchronized (self) 
    {
        _streamingCounter -= 1;
    }
}

@end
