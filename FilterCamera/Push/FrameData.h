//
//  FrameData.h
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FrameData : NSObject

@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) uint64_t timestamp;


@end

@interface FrameVideoData : FrameData

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, assign, readonly) BOOL isSpsAndPps;
@property (nonatomic, strong) NSData *spsData;
@property (nonatomic, strong) NSData *ppsData;

@end

@interface FrameAudioData : FrameData

@property (nonatomic, strong) NSData *info;

@end

NS_ASSUME_NONNULL_END
