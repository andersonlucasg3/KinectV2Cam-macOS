#pragma once

#import <CoreMediaIO/CoreMediaIO.h>
#import "KV2VirtualCamLibKinect.h"

@class KV2VirtualCamStreamSource;

@interface KV2VirtualCamDeviceSource : NSObject <CMIOExtensionDeviceSource>
{
    KV2VirtualCamLibKinect* _libKinect;
    KV2VirtualCamKinectDevice* _kinectDevice;
    KV2VirtualCamStreamSource* _streamSource;
    
    uint32_t _streamingCounter;
    
    CMFormatDescriptionRef _videoDescription;
    CVPixelBufferPoolRef _bufferPool;
    NSDictionary* _bufferAuxAttributes;
}

+ (instancetype)deviceWithLocalizedName:(NSString *)localizedName deviceSerialNumber:(NSString*)deviceSN libKinect:(KV2VirtualCamLibKinect*)libKinect;
- (instancetype)initWithLocalizedName:(NSString *)localizedName deviceSerialNumber:(NSString*)deviceSN libKinect:(KV2VirtualCamLibKinect*)libKinect;

@property(nonatomic, readonly) CMIOExtensionDevice *device;
@property(nonatomic, strong) __attribute__((NSObject)) CMFormatDescriptionRef videoDescription;
@property(nonatomic, strong) __attribute__((NSObject)) CVPixelBufferPoolRef bufferPool;
@property(nonatomic, strong) NSDictionary *bufferAuxAttributes;

- (void)startStreaming;
- (void)stopStreaming;

@end
