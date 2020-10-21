//
//  MainViewController.m
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import "MainViewController.h"
#import "FCPhotosViewController.h"
#import "FCCameraViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setUp];
    // Do any additional setup after loading the view.
}

- (void)setUp {
    UITabBarItem *photoItem = [[UITabBarItem alloc] initWithTitle:@"照片" image:nil selectedImage:nil];
    UINavigationController *photoNAV = [[UINavigationController alloc] initWithRootViewController:[FCPhotosViewController new]];
    photoNAV.tabBarItem = photoItem;
    UITabBarItem *cameraItem = [[UITabBarItem alloc] initWithTitle:@"直播" image:nil selectedImage:nil];
    UINavigationController *cameraNAV = [[UINavigationController alloc] initWithRootViewController:[FCCameraViewController new]];
    cameraNAV.tabBarItem = cameraItem;
    self.viewControllers = @[photoNAV, cameraNAV];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
