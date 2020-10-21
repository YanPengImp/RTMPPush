//
//  VideoDecoder.m
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import "VideoDecoder.h"

@interface VideoDecoder ()

@property (nonatomic, strong) dispatch_queue_t decoderQueue;

@end

@implementation VideoDecoder
{
    uint8_t *sps;
    uint8_t *pps;
    NSUInteger spsSize;
    NSUInteger ppsSize;
    CMFormatDescriptionRef formatDescription;
    VTDecompressionSessionRef session;
}

void vtDecompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTDecodeInfoFlags infoFlags,
                                    CM_NULLABLE CVImageBufferRef imageBuffer,
                                    CMTime presentationTimeStamp,
                                   CMTime presentationDuration ) {
    if (status == noErr) {
        CVPixelBufferRetain(imageBuffer);
        VideoDecoder *decoder = (__bridge VideoDecoder *)sourceFrameRefCon;
        if (decoder.delegate && [decoder.delegate respondsToSelector:@selector(didFinishDecoder:)]) {
            [decoder.delegate didFinishDecoder:imageBuffer];
        }
    }
    if (status == kVTVideoDecoderBadDataErr) {
        NSLog(@"decode callback failed status = %d(Bad data)", (int)status);
    }
}



- (BOOL)initDecoder {
    if (session) {
        return YES;
    }
    const uint8_t* const parameterSetPointers[2] = {sps, pps};
    const size_t parameterSetSize[2] = {spsSize, ppsSize};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSize, 4, &formatDescription);
    if (status == noErr) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(formatDescription);
        // kCVPixelBufferPixelFormatTypeKey 解码图像的采样格式
        // kCVPixelBufferWidthKey、kCVPixelBufferHeightKey 解码图像的宽高
        // kCVPixelBufferOpenGLCompatibilityKey制定支持OpenGL渲染，经测试有没有这个参数好像没什么差别
        NSDictionary* destinationPixelBufferAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), (id)kCVPixelBufferWidthKey : @(dimension.width), (id)kCVPixelBufferHeightKey : @(dimension.height),
                                                           (id)kCVPixelBufferOpenGLCompatibilityKey : @(YES)};
        //创建回调
        VTDecompressionOutputCallbackRecord record;
        record.decompressionOutputCallback = vtDecompressionOutputCallback;
        record.decompressionOutputRefCon = (__bridge void *)self;
        //创建解码器
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, formatDescription, NULL, (__bridge CFDictionaryRef)destinationPixelBufferAttributes, &record, &session);
        if (status == noErr) {
            VTSessionSetProperty(session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
            VTSessionSetProperty(session, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
            return YES;
        }
    }
    NSLog(@"init decoder session faild");
    return NO;
}

- (void)decoderVideoData:(NSData *)data {
    uint8_t *frame = (uint8_t *)data.bytes;
    uint32_t frameSize = (uint32_t)data.length;
    // frame的前4位是NALU数据的开始码，也就是00 00 00 01，第5个字节是表示数据类型，转为10进制后，7是sps,8是pps,5是IDR（I帧）信息
    int nalu_type = (frame[4] & 0x1F);
    uint32_t naluSize = frameSize - 4;
    uint8_t *pNaluSize = (uint8_t*)(&naluSize);
    frame[0] = *(pNaluSize + 3);
    frame[1] = *(pNaluSize + 2);
    frame[2] = *(pNaluSize + 1);
    frame[3] = *(pNaluSize);

    switch (nalu_type) {
        case 0x05:// i
            NSLog(@"NALU type is IDR frame");
            if ([self initDecoder]) {
                [self decoderData:frame frameSize:frameSize];
            }
            break;
        case 0x07:// sps
            NSLog(@"NALU type is sps frame");
            spsSize = frameSize - 4;
            sps = malloc(spsSize);
            memcpy(sps, &frame[4], spsSize);
            break;
        case 0x08:// pps
            NSLog(@"NALU type is pps frame");
            ppsSize = frameSize - 4;
            pps = malloc(ppsSize);
            memcpy(pps, &frame[4], ppsSize);
            break;

        default:
            NSLog(@"NALU type %d is B/P frame", nalu_type);
            if ([self initDecoder]) {
                [self decoderData:frame frameSize:frameSize];
            }
            break;
    }
}

- (void)decoderData:(uint8_t *)data frameSize:(uint32_t)frameSize {
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, data, frameSize, kCFAllocatorNull, NULL, 0, frameSize, FALSE, &blockBuffer);
    if (status == noErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, formatDescription, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
        if (sampleBuffer == NULL || status != kCMBlockBufferNoErr) {
            NSLog(@"decoder blockbuffer error");
            return;
        }
        // VTDecodeFrameFlags 0为允许多线程解码
        VTDecodeInfoFlags infoFlag = 0;
        VTDecodeFrameFlags frameFlag = 0;
        status = VTDecompressionSessionDecodeFrame(session, sampleBuffer, frameFlag, (__bridge void *)self, &infoFlag);
        CFRelease(blockBuffer);
        CFRelease(sampleBuffer);
    }
}

@end
