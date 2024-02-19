#pragma once

#import <CoreMediaIO/CoreMediaIO.h>

@interface KV2VirtualCamStreamSource : NSObject <CMIOExtensionStreamSource>
{
    __unsafe_unretained CMIOExtensionDevice *_device;
    CMIOExtensionStreamFormat *_streamFormat;
    NSUInteger _activeFormatIndex;
}

- (instancetype)initWithLocalizedName:(NSString *)localizedName streamID:(NSUUID *)streamID streamFormat:(CMIOExtensionStreamFormat *)streamFormat device:(CMIOExtensionDevice *)device;

@property(nonatomic, readonly) CMIOExtensionStream *stream;

@end
