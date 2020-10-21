//
//  VideoCoder.h
//  FilterCamera
//
//  Created by Imp on 2020/9/21.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "FrameData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VideoCoderDelegate <NSObject>

//用于h264的文件 包含了00 00 00 01
- (void)didEncodeData:(NSData *)data isKeyframe:(BOOL)isKeyframe;
- (void)didEncodeSpsData:(NSData *)spsDta ppsData:(NSData *)ppsData;

//用于推流没有 00 00 00 01分隔的原始数据
- (void)encodeFrameData:(FrameData *)frame;

@end

@interface VideoCoder : NSObject

@property (nonatomic, weak) id<VideoCoderDelegate> delegate;

- (void)encodeVideo:(CMSampleBufferRef)sampleBuffer timestamp:(uint64_t)timestamp;
- (void)endEncode;

@end

NS_ASSUME_NONNULL_END
