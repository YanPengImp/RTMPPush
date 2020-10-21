//
//  FCFliterCameraViewController.m
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import "FCFliterCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "FCImageFliter.h"
#import "VideoCoder.h"
#import "VideoDecoder.h"
#import "RTMPConnect.h"
#import "AudioEncoder.h"

@interface FCFliterCameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, VideoDecoderDelegate, VideoCoderDelegate, AudioEncoderDelegate, RTMPConnectStatedChangedDelegate>

//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property(nonatomic)AVCaptureDevice *device;
@property(nonatomic)AVCaptureDevice *audioDevice;

//AVCaptureDeviceInput 代表输入设备，他使用AVCaptureDevice 来初始化
@property(nonatomic)AVCaptureDeviceInput *input;
@property(nonatomic)AVCaptureDeviceInput *audioInput;

//当启动摄像头开始捕获输入
@property(nonatomic)AVCaptureVideoDataOutput *output;

@property(nonatomic)AVCaptureAudioDataOutput *audioOutput;

//照片输出流
@property (nonatomic)AVCaptureStillImageOutput *ImageOutPut;

//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property(nonatomic)AVCaptureSession *session;

//图像预览层，实时显示捕获的图像
@property(nonatomic)AVCaptureVideoPreviewLayer *previewLayer;

// ------------- UI --------------
//拍照按钮
@property (nonatomic)UIButton *photoButton;
//闪光灯按钮
@property (nonatomic)UIButton *flashButton;
//聚焦
@property (nonatomic)UIView *focusView;
//是否开启闪光灯
@property (nonatomic)BOOL isflashOn;

@property (nonatomic) UIImageView *imageView;

@property (nonatomic) UILabel *fpsLable;

@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, strong) VideoCoder *videoCoder;
@property (nonatomic, strong) VideoDecoder *videoDecoder;
@property (nonatomic, strong) AudioEncoder *audioEncoder;
@property (nonatomic, strong) RTMPConnect *rtmpConnect;
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) uint64_t currentTime;
@property (nonatomic, assign) BOOL isFirstFrame;

@end

@implementation FCFliterCameraViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.session startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.session stopRunning];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor lightGrayColor];
    [self startRtmp];
    [self initCaputure];
    [self initViews];
    // Do any additional setup after loading the view.
}

- (void)startRtmp {
    _rtmpConnect = [[RTMPConnect alloc] init];
    _rtmpConnect.delegate = self;
}

static int captureVideoFPS;
- (void)calculatorCaptureFPS
{
    static int count = 0;
    static float lastTime = 0;
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    float nowTime = CMTimeGetSeconds(hostTime);
    if(nowTime - lastTime >= 1)
    {
        captureVideoFPS = count;
        lastTime = nowTime;
        count = 0;
    }
    else
    {
        count ++;
    }
}

// 获取视频帧率
+ (int)getCaptureVideoFPS
{
    return captureVideoFPS;
}

- (void)initCaputure {
    self.device = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:nil];
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    //抛弃过期帧 保证实时性 默认也是YES
    self.output.alwaysDiscardsLateVideoFrames = YES;
    [self.output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    self.ImageOutPut = [[AVCaptureStillImageOutput alloc] init];
    //初始化会话，用来结合输入输出
    self.session = [[AVCaptureSession alloc] init];
    //设置分辨率 (设备支持的最高分辨率)
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        // 如果支持则设置
        [self.session canSetSessionPreset:AVCaptureSessionPreset1280x720];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
        [self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [self.session canSetSessionPreset:AVCaptureSessionPreset640x480];
    }

    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    if ([self.session canAddOutput:self.ImageOutPut]) {
        [self.session addOutput:self.ImageOutPut];
    }
    if ([self.session canAddOutput:self.output]) {
        [self.session addOutput:self.output];
    }
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    AVCaptureConnection *connection = [self.output connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    connection.videoMirrored = YES;

    _videoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _audioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    _lock = dispatch_semaphore_create(1);
    [self.output setSampleBufferDelegate:self queue:_videoQueue];
    [self.audioOutput setSampleBufferDelegate:self queue:_audioQueue];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    self.previewLayer.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];

    //开始启动
    [self.session startRunning];

    //修改设备的属性，先加锁
    if ([self.device lockForConfiguration:nil]) {
        //闪光灯自动
        if ([self.device isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [self.device setFlashMode:AVCaptureFlashModeAuto];
        }
        //自动白平衡
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        //设置帧率
        CMTime frameDuration = CMTimeMake(1, 30);
        BOOL frameRateSupported = NO;
        for (AVFrameRateRange *range in [self.device.activeFormat videoSupportedFrameRateRanges]) {
            if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
                CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
                frameRateSupported = YES;
            }
        }
        if (frameRateSupported) {
            [self.device setActiveVideoMaxFrameDuration:frameDuration];
            [self.device setActiveVideoMinFrameDuration:frameDuration];
        }
        [self.device unlockForConfiguration];
    }

    self.videoCoder = [[VideoCoder alloc] init];
    self.videoCoder.delegate = self;
    self.videoDecoder = [[VideoDecoder alloc] init];
    self.videoDecoder.delegate = self;
    self.audioEncoder = [[AudioEncoder alloc] init];
    self.audioEncoder.delegate = self;
}

- (void)initViews {

    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(40, self.view.bounds.size.height - self.view.bounds.size.height * (100.0 / self.view.bounds.size.width) - 100, 100, self.view.bounds.size.height * (100.0 / self.view.bounds.size.width))];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:_imageView];

    _photoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_photoButton setTitle:@"开始直播" forState:UIControlStateNormal];
    [_photoButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [_photoButton setBackgroundColor:[UIColor grayColor]];
    _photoButton.layer.cornerRadius = 10;
    _photoButton.layer.masksToBounds = YES;
    CGFloat width = 120;
    CGFloat height = 40;
    _photoButton.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width - width) / 2, UIScreen.mainScreen.bounds.size.height - height - 40 - 40, width, height);
    [_photoButton addTarget:self action:@selector(startLive) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_photoButton];

    _focusView = [[UIView alloc] init];
    _focusView.frame = CGRectMake(0, 0, 100, 100);
    _focusView.backgroundColor = [UIColor clearColor];
    _focusView.layer.borderColor = [UIColor redColor].CGColor;
    _focusView.layer.borderWidth = 0.5;
    [self.view addSubview:_focusView];
    [_focusView setHidden:YES];

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.frame = CGRectMake(20, 40, 60, 40);
    [cancelButton addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancelButton];

    UIButton *rotateButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [rotateButton setTitle:@"旋转" forState:UIControlStateNormal];
    rotateButton.frame = CGRectMake(self.view.frame.size.width - 100, 40, 60, 40);
    [rotateButton addTarget:self action:@selector(rotateButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:rotateButton];

    _fpsLable = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 100, 100, 100, 30)];
    _fpsLable.textColor = [UIColor redColor];
    [self.view addSubview:_fpsLable];
    __weak typeof(self)weakSelf = self;
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(calculatorCaptureFPS)];
    [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        weakSelf.fpsLable.text = [NSString stringWithFormat:@"%d",[[self class] getCaptureVideoFPS]];
    }];
}

- (void)rotateButtonAction {
    //获取摄像头的数量（该方法会返回当前能够输入视频的全部设备，包括前后摄像头和外接设备）
    NSInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    //摄像头的数量小于等于1的时候直接返回
    if (cameraCount <= 1) {
        return;
    }
    AVCaptureDevice *newCamera = nil;
    AVCaptureDeviceInput *newInput = nil;
    //获取当前相机的方向（前/后）
    AVCaptureDevicePosition position = [[self.input device] position];
    AVCaptureDevicePosition newPosition = AVCaptureDevicePositionFront;

    if (position == AVCaptureDevicePositionFront) {
        newCamera = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
        newPosition = AVCaptureDevicePositionBack;
    }else if (position == AVCaptureDevicePositionBack){
        newCamera = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];
        newPosition = AVCaptureDevicePositionFront;
    }
    //输入流
    newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
    if (newInput != nil) {
        [self.session beginConfiguration];
        //先移除原来的input
        [self.session removeInput:self.input];
        if ([self.session canAddInput:newInput]) {
            [self.session addInput:newInput];
            self.input = newInput;
        }else{
            //如果不能加现在的input，就加原来的input
            [self.session addInput:self.input];
        }
        AVCaptureConnection *connection = [self.output connectionWithMediaType:AVMediaTypeVideo];
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        connection.videoMirrored = newPosition == AVCaptureDevicePositionFront;
        [self.session commitConfiguration];
    }

}

- (void)startLive {
    if ([self.rtmpConnect isConnected]) {
        [self.rtmpConnect stop];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.rtmpConnect startWithUrl:@"rtmp://192.168.0.159:8001/yp/room"];
        });
    }
}

- (void)takePhotoAction {
    AVCaptureConnection *connection = self.session.outputs.firstObject.connections.firstObject;
    self.ImageOutPut = self.session.outputs.firstObject;
//    AVCaptureConnection *connection = [self.ImageOutPut connectionWithMediaType:AVMediaTypeVideo];
    [self.ImageOutPut captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        if (imageDataSampleBuffer == nil) {
            return;
        }
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        CFDictionaryRef newMetaDataRef = CMCopyDictionaryOfAttachments(NULL, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
        NSDictionary *metaDataDict = (__bridge NSDictionary *)newMetaDataRef;
        UIImage *image = [UIImage imageWithData:imageData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.imageView setHidden:NO];
            self.imageView.image = image;
            if (self.takePhoto) {
                self.takePhoto(image);
            }
        });
    }];
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)focusGesture:(UITapGestureRecognizer*)gesture{
    CGPoint point = [gesture locationInView:gesture.view];
    [self focusAtPoint:point];
}

- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    // focusPoint 函数后面Point取值范围是取景框左上角（0，0）到取景框右下角（1，1）之间,按这个来但位置就是不对，只能按上面的写法才可以。前面是点击位置的y/PreviewLayer的高度，后面是1-点击位置的x/PreviewLayer的宽度
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1 - point.x/size.width );

    if ([self.device lockForConfiguration:nil]) {
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [self.device setExposurePointOfInterest:focusPoint];
            //曝光量调节
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        [self.device unlockForConfiguration];

        _focusView.center = point;
        _focusView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            self.focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                self.focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                self.focusView.hidden = YES;
            }];
        }];
    }

}

-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [touches.anyObject locationInView:self.view];
    [self focusAtPoint:point];
}

- (uint64_t)currentTime{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == true) {
        _timestamp = CACurrentMediaTime() * 1000;
        _isFirstFrame = false;
        currentts = 0;
    }
    else {
        currentts = CACurrentMediaTime() * 1000 - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    BOOL audio = YES;
    if ([output isEqual:self.output]) {
        audio = NO;
    }
    NSLog(@"%@ didDropSampleBuffer", audio ? @"audio": @"video");
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection  {
//    NSLog(@"didOutputSampleBuffer");
    if (![self.rtmpConnect isConnected]) {
        return;
    }
    if ([output isEqual:self.output]) {
        [_videoCoder encodeVideo:sampleBuffer timestamp:self.currentTime];
    }
    if ([output isEqual:self.audioOutput]) {
        [_audioEncoder encodeAudio:sampleBuffer timestamp:self.currentTime];
    }
    return;


    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    void *baseAddress = (void *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);

    CGImageRef newImage = CGBitmapContextCreateImage(newContext);

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    if (!newImage) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = [UIImage imageWithCGImage:newImage];
//        UIImage *image = [FCImageFliter dealCGImage:newImage fliterType:FCImageFliterTypeLemo];
//        self.imageView.image = image;
        CGImageRelease(newImage);
    });
}

- (NSData *)convertVideoBufferToYUVData:(CMSampleBufferRef)samplebuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(samplebuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    void *baseAddress = (void *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t y_size = width * height;
    size_t uv_size = y_size / 2;
    uint8_t *yuv_frame = malloc(y_size + uv_size);
    return [NSData new];
}

#pragma mark - VideoCoderDelegate

- (void)encodeFrameData:(FrameData *)frame {
    if ([self.rtmpConnect isConnected]) {
        [self.rtmpConnect sendFrame:frame];
    }
}

- (void)didEncodeSpsData:(NSData *)spsDta ppsData:(NSData *)ppsData {
    [self.videoDecoder decoderVideoData:spsDta];
    [self.videoDecoder decoderVideoData:ppsData];
}

- (void)didEncodeData:(NSData *)data isKeyframe:(BOOL)isKeyframe {
    [self.videoDecoder decoderVideoData:data];
}

#pragma mark - AudioEncoderDelegate

- (void)encodeAudioFrameData:(FrameData *)frame {
    if ([self.rtmpConnect isConnected]) {
        [self.rtmpConnect sendFrame:frame];
    }
}

#pragma mark - VideoDecoderDelegate

- (void)didFinishDecoder:(CVPixelBufferRef)buffer {
    CIImage *image = [CIImage imageWithCVImageBuffer:buffer];
    CIContext *content = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [content createCGImage:image fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = [UIImage imageWithCGImage:cgimage];
        CFRelease(cgimage);
        CVPixelBufferRelease(buffer);
    });
}

#pragma mark - RTMPConnectStatedChangedDelegate

- (void)rtmpConnect:(RTMPConnect *)connect statedChange:(RTMPConnectStated)stated {
    switch (stated) {
        case RTMPConnectStatedConnected:
            [_photoButton setTitle:@"停止直播" forState:UIControlStateNormal];
            _photoButton.enabled = YES;
            _isFirstFrame = YES;
            break;
        case RTMPConnectStatedConnectErr:
        case RTMPConnectStatedUnConnected:
        case RTMPConnectStatedEnd:
            [_photoButton setTitle:@"开始直播" forState:UIControlStateNormal];
            _photoButton.enabled = YES;
            _isFirstFrame = NO;
            break;
        case RTMPConnectStatedConnecting:
            [_photoButton setTitle:@"连接中" forState:UIControlStateNormal];
            _photoButton.enabled = NO;
        default:
            break;
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
