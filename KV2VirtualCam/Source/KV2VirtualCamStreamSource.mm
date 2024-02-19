#import "KV2VirtualCamStreamSource.h"
#import "KV2VirtualCamDeviceSource.h"
#import "KV2VirtualCamConstants.h"
#import "KV2VirtualCamLogging.h"

@implementation KV2VirtualCamStreamSource

- (instancetype)initWithLocalizedName:(NSString *)localizedName streamID:(NSUUID *)streamID streamFormat:(CMIOExtensionStreamFormat *)streamFormat device:(CMIOExtensionDevice *)device
{
    self = [super init];
    if (self) {
        _device = device;
        _streamFormat = streamFormat;
        _stream = [[CMIOExtensionStream alloc] initWithLocalizedName:localizedName streamID:streamID direction:CMIOExtensionStreamDirectionSource clockType:CMIOExtensionStreamClockTypeHostTime source:self];
    }
    return self;
}

- (NSArray<CMIOExtensionStreamFormat *> *)formats
{
    return [NSArray arrayWithObjects:_streamFormat, nil];
}

- (NSUInteger)activeFormatIndex
{
    return 0;
}

- (void)setActiveFormatIndex:(NSUInteger)activeFormatIndex
{
    if (activeFormatIndex >= 1) 
    {
        os_log(KV2VirtualCamLog, "Invalid index");
    }
}

- (NSSet<CMIOExtensionProperty> *)availableProperties
{
    return [NSSet setWithObjects:CMIOExtensionPropertyStreamActiveFormatIndex, CMIOExtensionPropertyStreamFrameDuration, nil];
}

- (nullable CMIOExtensionStreamProperties *)streamPropertiesForProperties:(NSSet<CMIOExtensionProperty> *)properties error:(NSError * _Nullable *)outError
{
    CMIOExtensionStreamProperties *streamProperties = [CMIOExtensionStreamProperties streamPropertiesWithDictionary:@{}];
    if ([properties containsObject:CMIOExtensionPropertyStreamActiveFormatIndex]) {
        streamProperties.activeFormatIndex = @(self.activeFormatIndex);
    }
    if ([properties containsObject:CMIOExtensionPropertyStreamFrameDuration]) {
        CMTime frameDuration = CMTimeMake(1, kFrameRate);
        NSDictionary *frameDurationDictionary = CFBridgingRelease(CMTimeCopyAsDictionary(frameDuration, NULL));
        streamProperties.frameDuration = frameDurationDictionary;
    }
    return streamProperties;
}

- (BOOL)setStreamProperties:(CMIOExtensionStreamProperties *)streamProperties error:(NSError * _Nullable *)outError
{
    if (streamProperties.activeFormatIndex) {
        [self setActiveFormatIndex:streamProperties.activeFormatIndex.unsignedIntegerValue];
    }
    return YES;
}

- (BOOL)authorizedToStartStreamForClient:(CMIOExtensionClient *)client
{
    // An opportunity to inspect the client info and decide if it should be allowed to start the stream.
    return YES;
}

- (BOOL)startStreamAndReturnError:(NSError * _Nullable *)outError
{
    KV2VirtualCamDeviceSource *deviceSource = (KV2VirtualCamDeviceSource *)_device.source;
    [deviceSource startStreaming];
    return YES;
}

- (BOOL)stopStreamAndReturnError:(NSError * _Nullable *)outError
{
    KV2VirtualCamDeviceSource *deviceSource = (KV2VirtualCamDeviceSource *)_device.source;
    [deviceSource stopStreaming];
    return YES;
}

@end
