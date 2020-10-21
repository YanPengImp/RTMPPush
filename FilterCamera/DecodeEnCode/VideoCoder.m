//
//  VideoCoder.m
//  FilterCamera
//
//  Created by Imp on 2020/9/21.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import "VideoCoder.h"

@interface VideoCoder ()

@property (nonatomic, strong) NSData *spsData;
@property (nonatomic, strong) NSData *ppsData;
@property (nonatomic, strong) NSData *naluData;
@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) dispatch_queue_t encoderQueue;

@end

@implementation VideoCoder
{
    int32_t width;
    int32_t height;
    int32_t bitrate;
    int32_t fps;
    int32_t frameId;
    VTCompressionSessionRef session;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        width = 540;
        height = 960;
        bitrate = width * height * 3 * 4;
        fps = 24;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *str = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *sourcePath = [str stringByAppendingPathComponent:@"test.h264"];   // 源文件路径
        if ([fileManager fileExistsAtPath:sourcePath]) {
            [fileManager removeItemAtPath:sourcePath error:nil];
        }
        [fileManager createFileAtPath:sourcePath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:sourcePath];
        [_fileHandle seekToEndOfFile];
        _encoderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        [self openEncoder];
    }
    return self;
}

static void vtCompressionSessionCallback (void * CM_NULLABLE outputCallbackRefCon,
                                            void * CM_NULLABLE sourceFrameRefCon,
                                            OSStatus status,
                                            VTEncodeInfoFlags infoFlags,
                                            CM_NULLABLE CMSampleBufferRef sampleBuffer ){
    if (status != noErr) {
        NSLog(@"encode status faild");
        return;
    }
    //没准备好
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"encode data is not ready ");
        return;
    }
    uint64_t timeStamp = [((__bridge_transfer NSNumber*)sourceFrameRefCon) longLongValue];
    VideoCoder *coder = (__bridge VideoCoder *)outputCallbackRefCon;
    BOOL isKeyFrame = !CFDictionaryContainsKey((CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    //获取sps pps信息
    if (isKeyFrame && !coder.spsData) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (spsStatus == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (ppsStatus == noErr) {
                coder.spsData = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                coder.ppsData = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                FrameVideoData *frame = [[FrameVideoData alloc] init];
                frame.spsData = coder.spsData;
                frame.ppsData = coder.ppsData;
                frame.timestamp = timeStamp;
                if (coder.delegate && [coder.delegate respondsToSelector:@selector(encodeFrameData:)]) {
                    [coder.delegate encodeFrameData:frame];
                }
                [coder writeSps:coder.spsData pps:coder.ppsData];
            }
        }
    }
    //真正的视频帧
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus codeStatus = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer);
    if (codeStatus == noErr) {
        size_t currReadPos = 0;
        //一般情况下都是只有1帧，在最开始编码的时候有2帧，取最后一帧
        while (currReadPos < totalLength - 4) {
            uint32_t naluLen = 0;
            memcpy(&naluLen, dataPointer + currReadPos, 4);
            naluLen = CFSwapInt32BigToHost(naluLen);

            //naluData 即为一帧h264数据。
            //如果保存到文件中，需要将此数据前加上 [0 0 0 1] 4个字节，按顺序写入到h264文件中。
            //如果推流，需要将此数据前加上4个字节表示数据长度的数字，此数据需转为大端字节序。
            //关于大端和小端模式，请参考此网址：http://blog.csdn.net/hackbuteer1/article/details/7722667
            coder.naluData = [NSData dataWithBytes:dataPointer + currReadPos + 4 length:naluLen];
            coder.isKeyFrame = isKeyFrame;
            [coder writeVideoData:coder.naluData isKeyframe:isKeyFrame];
            FrameVideoData *frame = [[FrameVideoData alloc] init];
            frame.data = coder.naluData;
            frame.isKeyFrame = isKeyFrame;
            frame.timestamp = timeStamp;
            NSLog(@"是否关键帧  %d 时间戳 %llu", isKeyFrame, timeStamp);
            if (coder.delegate && [coder.delegate respondsToSelector:@selector(encodeFrameData:)]) {
                [coder.delegate encodeFrameData:frame];
            }
            currReadPos += 4 + naluLen;
        }
    }
}


- (void)openEncoder {
    OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, vtCompressionSessionCallback, (__bridge void *)self, &session);
    if (status == noErr) {
        // 设置参数
        // ProfileLevel，h264的协议等级，不同的清晰度使用不同的ProfileLevel。
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_5_0);
        // 设置码率
        VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bitrate));
        VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(bitrate * 2/8), @1]);
        // 设置实时编码
        VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        // 关闭重排Frame，因为有了B帧（双向预测帧，根据前后的图像计算出本帧）后，编码顺序可能跟显示顺序不同。此参数可以关闭B帧。
        VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        // 关键帧最大间隔，关键帧也就是I帧。此处表示关键帧最大间隔为2s。
        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps * 2));
        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(fps * 2));
        //设置帧率 不是实际的 只是初始化
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(fps));
        // 关于B帧 P帧 和I帧，请参考：http://blog.csdn.net/abcjennifer/article/details/6577934

        // 设置H264 熵编码模式 H264标准采用了两种熵编码模式
        // 熵编码即编码过程中按熵原理不丢失任何信息的编码。信息熵为信源的平均信息量（不确定性的度量）
        VTSessionSetProperty(session, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);

        //参数设置完毕，准备开始，至此初始化完成，随时来数据，随时编码
        status = VTCompressionSessionPrepareToEncodeFrames(session);
        if (status != noErr) {
            NSLog(@"encode prepare faild");
        }
    }
}

- (void)encodeVideo:(CMSampleBufferRef)sampleBuffer timestamp:(uint64_t)timestamp {
    if (session == NULL) {
        NSLog(@"session faild");
        return;
    }
    dispatch_sync(_encoderQueue, ^{
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime pts = CMTimeMake(frameId++, 1000);
        VTEncodeInfoFlags flags;
        // 关键帧的最大间隔 设为 帧率的二倍
        NSDictionary *properties = nil;
        if(frameId % (int32_t)(fps * 2) == 0){
            properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
        }
        NSNumber *timeNumber = @(timestamp);
        OSStatus status = VTCompressionSessionEncodeFrame(session, imageBuffer, pts, kCMTimeInvalid, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
        if (status != noErr) {
            NSLog(@"encode h264 faild");
            [self endEncode];
        }
    });
}

- (NSData *)headerData {
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;  //string literals have implicit trailing '\0'
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    return byteHeader;
}

- (void)writeSps:(NSData *)spsData pps:(NSData *)ppsData {
    // 1.拼接NALU的header

    // 2.将NALU的头&NALU的体写入文件
    NSMutableData *spsMutableData = [NSMutableData data];
    [spsMutableData appendData:[self headerData]];
    [spsMutableData appendData:spsData];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:spsMutableData];

    NSMutableData *ppsMutableData = [NSMutableData data];
    [ppsMutableData appendData:[self headerData]];
    [ppsMutableData appendData:ppsData];
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:ppsMutableData];
    if (self.delegate && [self.delegate respondsToSelector:@selector(didEncodeSpsData: ppsData:)]) {
        [self.delegate didEncodeSpsData:spsMutableData ppsData:ppsMutableData];
    }
}

- (void)writeVideoData:(NSData *)data isKeyframe:(BOOL)isKeyframe {
    NSMutableData *mutableData = [NSMutableData data];
    [mutableData appendData:[self headerData]];
    [mutableData appendData:data];
    [self.fileHandle writeData:mutableData];

    if (self.delegate && [self.delegate respondsToSelector:@selector(didEncodeData: isKeyframe:)]) {
        [self.delegate didEncodeData:mutableData isKeyframe:isKeyframe];
    }
}

- (void)endEncode {
    VTCompressionSessionInvalidate(session);
    CFRelease(session);
    session = NULL;
    frameId = 0;
    _spsData = nil;
    _ppsData = nil;
    _naluData = nil;
}


@end
