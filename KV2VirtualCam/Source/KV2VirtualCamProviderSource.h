#pragma once

#import <CoreMediaIO/CoreMediaIO.h>

@interface KV2VirtualCamProviderSource : NSObject <CMIOExtensionProviderSource>

- (instancetype)initWithClientQueue:(dispatch_queue_t)clientQueue;

@property(nonatomic, readonly) CMIOExtensionProvider *provider;

@end
