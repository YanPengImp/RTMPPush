//
//  RTMPConnect.h
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FrameData.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, RTMPConnectStated) {
    RTMPConnectStatedUnConnected,
    RTMPConnectStatedConnecting,
    RTMPConnectStatedConnected,
    RTMPConnectStatedConnectErr,
    RTMPConnectStatedEnd,
};

@class RTMPConnect;
@protocol RTMPConnectStatedChangedDelegate <NSObject>

- (void)rtmpConnect:(RTMPConnect *)connect statedChange:(RTMPConnectStated)stated;

@end

@interface RTMPConnect : NSObject

@property (nonatomic, weak) id<RTMPConnectStatedChangedDelegate> delegate;

- (BOOL)isConnected;

- (BOOL)startWithUrl:(NSString *)url;

- (void)stop;

- (void)sendFrame:(FrameData *)frame;

@end

NS_ASSUME_NONNULL_END
