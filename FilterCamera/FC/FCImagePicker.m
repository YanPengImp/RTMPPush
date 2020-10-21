//
//  FCImagePicker.m
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import "FCImagePicker.h"
#import <Photos/Photos.h>

@interface FCImagePicker() <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) UIViewController *delegate;
@property (nonatomic, copy) void(^complete)(UIImage *);

@end

@implementation FCImagePicker

+ (instancetype)sharedInstance {
    static FCImagePicker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FCImagePicker alloc] init];
    });
    return instance;
}

- (void)showImagePickerWithDelegate:(UIViewController *)viewController complete:(void (^)(UIImage *image))complete {
    _delegate = viewController;
    self.complete = complete;
    [self accessPhotoLibrary:^(BOOL success) {
        if (success) {
            [self presenImagePicker];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"请在iPhone中设置允许访问照片" preferredStyle:UIAlertControllerStyleAlert];
            [viewController presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)presenImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [_delegate presentViewController:picker animated:YES completion:nil];
}

- (void)accessPhotoLibrary:(void(^)(BOOL success))complete {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        complete(NO);
    } else {
        complete(YES);
    }
}

#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    picker.delegate = nil;
    [picker dismissViewControllerAnimated:YES completion:nil];
    self.complete(nil);
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage];
    picker.delegate = nil;
    [picker dismissViewControllerAnimated:YES completion:^{
        self.complete(image);
    }];
}

@end
