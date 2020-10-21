//
//  AudioEncoder.h
//  FilterCamera
//
//  Created by Imp on 2020/10/20.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "FrameData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AudioEncoderDelegate <NSObject>

- (void)encodeAudioFrameData:(FrameData *)frame;

@end

@interface AudioEncoder : NSObject

@property (nonatomic, weak) id<AudioEncoderDelegate> delegate;
- (void)encodeAudio:(CMSampleBufferRef)sampleBuffer timestamp:(uint64_t)timestamp;
- (void)endEncode;

@end

NS_ASSUME_NONNULL_END
