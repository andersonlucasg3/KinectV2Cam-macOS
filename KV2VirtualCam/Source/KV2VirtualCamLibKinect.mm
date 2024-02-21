#import "KV2VirtualCamLibKinect.h"
#import "KV2VirtualCamLogging.h"

#import <libfreenect2/frame_listener.hpp>
#import <libfreenect2/frame_listener_impl.h>

using namespace libfreenect2;

@interface KV2VirtualCamKinectDevice ()

@property (assign) Freenect2Device* device;
@property (assign) SyncMultiFrameListener* listener;

- (instancetype) initWithDevice:(Freenect2Device*)device;

@end

@implementation KV2VirtualCamKinectDevice

@synthesize device = _device;
@synthesize listener = _listener;

- (instancetype) initWithDevice:(Freenect2Device*)device
{
    if (self = [super init])
    {
        _device = device;
        
        _listener = new SyncMultiFrameListener(libfreenect2::Frame::Color);
        _device->setColorFrameListener(_listener);
    }
    return self;
}

- (void)dealloc
{
    if (_listener != nullptr)
    {
        delete _listener;
    }
}

@end

@implementation KV2VirtualCamLibKinect
{
    Freenect2 _freenect2;
    FrameMap _frames;
}

- (int)getDeviceCount
{
    return _freenect2.enumerateDevices();
}

- (NSString*) getDeviceSerialNumber:(int)index
{
    return [NSString stringWithCString:_freenect2.getDeviceSerialNumber(index).c_str() encoding:NSUTF8StringEncoding];
}

- (KV2VirtualCamKinectDevice *)openKinectDevice:(NSString *)serialNumber
{
    Freenect2Device* dev = _freenect2.openDevice([serialNumber cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (dev == nullptr) 
    {
#if DEBUG
        os_log(KV2VirtualCamLog, "Failed to open kinect device with SN: %s", [serialNumber cStringUsingEncoding:NSUTF8StringEncoding]);
#endif
        
        return nil;
    }
    
    return [[KV2VirtualCamKinectDevice alloc] initWithDevice:dev];
}

- (BOOL) closeKinectDevice:(KV2VirtualCamKinectDevice *)device
{
    return device.device->close();
}

- (BOOL) startStreamingDevice:(KV2VirtualCamKinectDevice*)device
{
    BOOL result = device.device->startStreams(true, false);
    
#if DEBUG
    os_log(KV2VirtualCamLog, "start streaming device success: %s", result ? "YES" : "NO");
#endif
    
    return result;
}

- (BOOL) stopStreamingDevice:(KV2VirtualCamKinectDevice*)device
{
    return device.device->stop();
}

- (void) waitForFrame:(KV2VirtualCamKinectDevice *)device processFrame:(void (^)(size_t, size_t, uint8, unsigned char *))block
{
    if (device.listener->waitForNewFrame(_frames, 1000)) // 1 sec
    {
        Frame *rgb = _frames[Frame::Color];
        
        block(rgb->width, rgb->height, rgb->bytes_per_pixel, rgb->data);
        
        device.listener->release(_frames);
    }
}

@end
