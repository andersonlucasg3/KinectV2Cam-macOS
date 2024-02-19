#import "Source/KV2VirtualCamLogging.h"
#import "Source/KV2VirtualCamProviderSource.h"

#import <Foundation/Foundation.h>

int main(int argc, char *argv[])
{
    os_log(KV2VirtualCamLog, "Starting KinectV2 Virtual Camera Extension");
    
    @autoreleasepool 
    {
        KV2VirtualCamProviderSource *providerSource = [[KV2VirtualCamProviderSource alloc] initWithClientQueue:nil];
        [CMIOExtensionProvider startServiceWithProvider:providerSource.provider];
        CFRunLoopRun();
    }
    
    return 0;
}
