#pragma once

#import <Foundation/Foundation.h>
#import <libfreenect2/libfreenect2.hpp>

@interface KV2VirtualCamKinectDevice : NSObject

@end

@interface KV2VirtualCamLibKinect : NSObject

- (int) getDeviceCount;
- (NSString*) getDeviceSerialNumber:(int)index;

- (KV2VirtualCamKinectDevice*) openKinectDevice:(NSString*)serialNumber;
- (BOOL) closeKinectDevice:(KV2VirtualCamKinectDevice*)device;
- (BOOL) startStreamingDevice:(KV2VirtualCamKinectDevice*)device;
- (BOOL) stopStreamingDevice:(KV2VirtualCamKinectDevice*)device;
- (void) waitForFrame:(KV2VirtualCamKinectDevice*)device processFrame:(void(^)(size_t width, size_t height, uint8 bytesPerPixel, unsigned char* frame))block;

@end

