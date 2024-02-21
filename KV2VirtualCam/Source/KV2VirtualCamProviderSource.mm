#import "KV2VirtualCamProviderSource.h"
#import "KV2VirtualCamDeviceSource.h"
#import "KV2VirtualCamLibKinect.h"
#import "KV2VirtualCamLogging.h"

@interface KV2VirtualCamProviderSource ()
{
    KV2VirtualCamLibKinect* _libKinect;
    NSMutableDictionary<NSString*, KV2VirtualCamDeviceSource*>* _devicesSources;
    NSTimer* _checkForDevicesTimer;
}

- (void) searchForKinectDevicesAndUpdateVirtualDevices;

@end

@implementation KV2VirtualCamProviderSource

- (instancetype) initWithClientQueue:(dispatch_queue_t)clientQueue
{
    self = [super init];
    if (self) {
        _provider = [[CMIOExtensionProvider alloc] initWithSource:self clientQueue:clientQueue];
 
        _libKinect = [[KV2VirtualCamLibKinect alloc] init];
        
#if DEBUG
        os_log(KV2VirtualCamLog, "Create reference to libkinect: %p", _libKinect);
#endif
        
        _devicesSources = [NSMutableDictionary new];
        
        __weak KV2VirtualCamProviderSource* weakSelf = self;
        _checkForDevicesTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer * _Nonnull timer) 
        {
            [weakSelf searchForKinectDevicesAndUpdateVirtualDevices];
        }];
    }
    return self;
}

- (void) searchForKinectDevicesAndUpdateVirtualDevices
{
    NSMutableDictionary* newDevicesSources = [_devicesSources mutableCopy];
    NSMutableArray* allDevicesSN = [NSMutableArray new];
    
    const int kinectCount = [_libKinect getDeviceCount];
    
#if DEBUG
    os_log_debug(KV2VirtualCamLog, "found %d devices", kinectCount);
#endif
    
    for (int index = 0; index < kinectCount; ++index)
    {
        NSString* deviceSN = [_libKinect getDeviceSerialNumber:index];
        NSString* deviceName = kinectCount == 1 ? @"KinectV2" : [NSString stringWithFormat:@"KinectV2 (%d)", index + 1];
        
        KV2VirtualCamDeviceSource* deviceSource = [_devicesSources objectForKey:deviceSN];
        
        if (deviceSource == nil)
        {
            KV2VirtualCamDeviceSource* deviceSource = [KV2VirtualCamDeviceSource deviceWithLocalizedName:deviceName deviceSerialNumber:deviceSN libKinect:_libKinect];
            
            NSError *error = nil;
            if ([_provider addDevice:deviceSource.device error:&error]) 
            {
                [newDevicesSources setObject:deviceSource forKey:deviceSN];
            }
            
#if DEBUG
            os_log(KV2VirtualCamLog, "Adding Kinect of name: %s, error: %s",
                   [deviceName cStringUsingEncoding:NSUTF8StringEncoding],
                   [[error debugDescription] cStringUsingEncoding:NSUTF8StringEncoding]);
#endif
        }
        
        [allDevicesSN addObject:deviceSN];
    }
    
    NSMutableArray* removingDevices = [[_devicesSources allKeys] mutableCopy];
    [removingDevices removeObjectsInArray:allDevicesSN];
    
    for (NSString* deviceName : removingDevices)
    {
        KV2VirtualCamDeviceSource* deviceSource = [newDevicesSources objectForKey:deviceName];
        
        NSError* error;
        if ([_provider removeDevice:deviceSource.device error:&error])
        {
            [newDevicesSources removeObjectForKey:deviceName];
        }
        
#if DEBUG
        os_log(KV2VirtualCamLog, "Removing Kinect of name: %s, error: %s",
               [deviceSource.device.localizedName cStringUsingEncoding:NSUTF8StringEncoding],
               [[error debugDescription] cStringUsingEncoding:NSUTF8StringEncoding]);
#endif
    }
    
    _devicesSources = newDevicesSources;
}

// CMIOExtensionProviderSource protocol methods (all are required)

- (BOOL)connectClient:(CMIOExtensionClient *)client error:(NSError * _Nullable *)outError
{
#if DEBUG
    
    NSString* clientID = [[client clientID] UUIDString];
    NSString* signingID = [client signingID];
    pid_t pid = [client pid];
    
    os_log(KV2VirtualCamLog, "client %p connect, clientID: %s, signingID: %s, pid: %d",
          client,
           [clientID cStringUsingEncoding:NSUTF8StringEncoding],
           [signingID  cStringUsingEncoding:NSUTF8StringEncoding],
           pid);
    
#endif
    
    return YES;
}

- (void)disconnectClient:(CMIOExtensionClient *)client
{
#if DEBUG
    
    NSString* clientID = [[client clientID] UUIDString];
    NSString* signingID = [client signingID];
    pid_t pid = [client pid];
    os_log(KV2VirtualCamLog, "client %p disconnect, clientID: %@, signingID: %@, pid: %d",
          client, clientID, signingID, pid);
    
#endif
}

- (NSSet<CMIOExtensionProperty> *)availableProperties
{
    // See full list of CMIOExtensionProperty choices in CMIOExtensionProperties.h
    return [NSSet setWithObjects:CMIOExtensionPropertyProviderManufacturer, nil];
}

- (nullable CMIOExtensionProviderProperties *) providerPropertiesForProperties:(NSSet<CMIOExtensionProperty> *)properties error:(NSError * _Nullable *)outError
{
    CMIOExtensionProviderProperties *providerProperties = [CMIOExtensionProviderProperties providerPropertiesWithDictionary:@{}];
    if ([properties containsObject:CMIOExtensionPropertyProviderManufacturer]) {
        providerProperties.manufacturer = @"Microsoft";
    }
    return providerProperties;
}

- (BOOL)setProviderProperties:(CMIOExtensionProviderProperties *)providerProperties error:(NSError * _Nullable *)outError
{
    // Handle settable properties here.
    return YES;
}

@end
