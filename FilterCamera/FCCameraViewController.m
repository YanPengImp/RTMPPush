//
//  FCCameraViewController.m
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import "FCCameraViewController.h"
#import "FCFliterCameraViewController.h"
#import "FCImageFliter.h"

@interface FCCameraViewController ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImage *image;

@end

@implementation FCCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"相机";
    [self initViews];
    // Do any additional setup after loading the view.
}

- (void)initViews {
    UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [selectButton setTitle:@"开始直播" forState:UIControlStateNormal];
    [selectButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [selectButton addTarget:self action:@selector(selectButtonAction) forControlEvents:UIControlEventTouchUpInside];
    selectButton.frame = CGRectMake(50, 100, 100, 30);
    [self.view addSubview:selectButton];

    UIButton *chooseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [chooseButton setTitle:@"选择滤镜" forState:UIControlStateNormal];
    [chooseButton addTarget:self action:@selector(chooseButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [chooseButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    chooseButton.frame = CGRectMake(200, 100, 100, 30);
    [self.view addSubview:chooseButton];

    _imageView = [[UIImageView alloc] init];
    _imageView.frame = CGRectMake(0, 0, 300, 300);
    _imageView.center = self.view.center;
    [self.view addSubview:_imageView];
}

- (void)selectButtonAction {
    FCFliterCameraViewController *cameraVC = [[FCFliterCameraViewController alloc] init];
    cameraVC.takePhoto = ^(UIImage *image) {
        self.image = image;
        self.imageView.image = image;
    };
    [self presentViewController:cameraVC animated:YES completion:nil];
}

- (void)chooseButtonAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"lemo" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeLemo];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"黑白" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeHeibai];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复古" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeFugu];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"哥特" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeGete];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"锐化" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeRuise];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"淡雅" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeDanya];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"酒红" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeJiuhong];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"青宁" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeQingning];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"浪漫" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeLangman];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"光晕" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeGuangyun];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"蓝调" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeLandiao];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"反色" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reloadImageViewWithType:FCImageFliterTypeFanse];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reloadImageViewWithType:(FCImageFliterType)type {
    UIImage *img = [FCImageFliter dealImage:self.image fliterType:type];
    self.imageView.image = img;
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
