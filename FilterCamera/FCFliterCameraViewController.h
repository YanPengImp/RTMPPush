//
//  FCFliterCameraViewController.h
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FCFliterCameraViewController : UIViewController

@property (nonatomic, copy) void(^takePhoto)(UIImage *image);

@end
