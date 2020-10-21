//
//  FCImageFliter.h
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    FCImageFliterTypeLemo = 0,
    FCImageFliterTypeHeibai,
    FCImageFliterTypeFugu,
    FCImageFliterTypeGete,
    FCImageFliterTypeRuise,
    FCImageFliterTypeDanya,
    FCImageFliterTypeJiuhong,
    FCImageFliterTypeQingning,
    FCImageFliterTypeLangman,
    FCImageFliterTypeGuangyun,
    FCImageFliterTypeLandiao,
    FCImageFliterTypeFanse,
} FCImageFliterType;

@interface FCImageFliter : NSObject

+ (UIImage *)dealImage:(UIImage *)img fliterType:(FCImageFliterType )type;

+ (UIImage *)dealCGImage:(CGImageRef)img fliterType:(FCImageFliterType )type;

@end
