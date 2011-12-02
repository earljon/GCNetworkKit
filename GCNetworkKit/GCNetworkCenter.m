//
//  GCNetworkCenter.m
//
//  Created by Giulio Petek on 11.09.11.
//  Copyright 2011 GrandCentrix. All rights reserved.
//
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

#import "GCNetworkCenter.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

NSString *const GCNetworkCenterConnectionDidChangeNotification = @"GCNetworkCenterConnectionDidChangeNotification";
NSString *const GCNetworkCenterConnectionDidChangeNotification_Intern = @"GCNetworkCenterConnectionDidChangeNotification_Intern";

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
// GCNetworkCenter()
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

@interface GCNetworkCenter ()

@property (nonatomic, readwrite) GCNetworkCenterConnectionType connectionType;
@property (nonatomic, readwrite) SCNetworkReachabilityRef _ref;

- (void)_conectionDidChange;
+ (void)_refreshActivityCount;

@end

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
// GCNetworkCenter
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

@implementation GCNetworkCenter
@synthesize listen = _listen;
@synthesize connectionType = _connectionType;
@synthesize _ref;

#pragma mark Init

+ (GCNetworkCenter *)defaultCenter {
    static dispatch_once_t pred;
    static GCNetworkCenter *__defaultCenter = nil;
    
    dispatch_once(&pred, ^{
        __defaultCenter = [[GCNetworkCenter alloc] init];
    });
    
    return __defaultCenter;
}

- (id)init {
    if ((self = [super init])) {
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        
        self._ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
        self.listen = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(_conectionDidChange) 
                                                     name:GCNetworkCenterConnectionDidChangeNotification_Intern 
                                                   object:nil];
    }
    
    return self;
}

#pragma mark Changes

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    [[NSNotificationCenter defaultCenter] postNotificationName:GCNetworkCenterConnectionDidChangeNotification_Intern
                                                        object:nil];
}

- (void)_conectionDidChange {
    self.connectionType = GCUnknownConnection;

    [[NSNotificationCenter defaultCenter] postNotificationName:GCNetworkCenterConnectionDidChangeNotification
                                                        object:nil];
}

#pragma mark @properies

- (void)setListen:(BOOL)_listen_ {
    if (_listen_) {
        SCNetworkReachabilityContext context = { 0, (__bridge void *)(self), NULL, NULL, NULL };
        if (SCNetworkReachabilitySetCallback(self._ref, ReachabilityCallback, &context))
            SCNetworkReachabilityScheduleWithRunLoop(self._ref, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            
        _listen = YES;
    }
    else {
        SCNetworkReachabilityUnscheduleFromRunLoop(self._ref, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

        _listen = NO;
    }
}

- (BOOL)isConnected {
    return (self.connectionType != GCNoConnection)?(YES):(NO);
}

#pragma mark Host Reacability

+ (BOOL)hostIsReachable:(NSString *)host {
    SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [host UTF8String]);
    SCNetworkReachabilityFlags reachabilityFlag;
    SCNetworkReachabilityGetFlags(reachabilityRef, &reachabilityFlag);
    
    return (reachabilityFlag & kSCNetworkFlagsReachable) && !(reachabilityFlag & kSCNetworkFlagsConnectionRequired);
}

#pragma mark Network Activity Indicator

static NSInteger __count = 0;

+ (void)_refreshActivityCount {
    @synchronized(self) {
        __count = MAX(__count, 0);
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:__count > 0];
    }
}

+ (void)addNetworkActivity {
    __count += 1;
    [self _refreshActivityCount];
}

+ (void)removeNetworkActivity {
    __count -= 1;
    [self _refreshActivityCount];
}

#pragma mark Memory

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
