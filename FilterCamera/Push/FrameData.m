//
//  FrameData.m
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import "FrameData.h"

@implementation FrameData

@end

@implementation  FrameVideoData

- (BOOL)isSpsAndPps {
    return _spsData && _ppsData;
}

@end

@implementation FrameAudioData

@end
