//
//  FCImagePicker.h
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FCImagePicker : NSObject

+ (instancetype)sharedInstance;

- (void)showImagePickerWithDelegate:(UIViewController *)viewController complete:(void(^)(UIImage *image))complete;

@end
