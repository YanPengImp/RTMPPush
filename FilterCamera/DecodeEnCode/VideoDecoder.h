//
//  VideoDecoder.h
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VideoDecoderDelegate <NSObject>

- (void)didFinishDecoder:(CVPixelBufferRef)buffer;

@end

@interface VideoDecoder : NSObject

@property (nonatomic, weak) id<VideoDecoderDelegate> delegate;
- (void)decoderVideoData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
