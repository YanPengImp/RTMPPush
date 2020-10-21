//
//  RTMPConnect.m
//  FilterCamera
//
//  Created by Imp on 2020/9/24.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import "RTMPConnect.h"
#include "rtmp.h"
#import <AVFoundation/AVFoundation.h>

@interface RTMPConnect ()

@property (nonatomic, assign) RTMPConnectStated stated;
@property (nonatomic, assign) BOOL sendHeader;
@property (nonatomic, strong) dispatch_queue_t connectQueue;

@end

@implementation RTMPConnect {
    RTMP *rtmp;
    uint64_t start_time;
}

- (dispatch_queue_t)connectQueue {
    if (!_connectQueue) {
        _connectQueue = dispatch_queue_create("com.rtmp.queue", NULL);
    }
    return _connectQueue;
}

- (void)setStated:(RTMPConnectStated)stated {
    _stated = stated;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(rtmpConnect:statedChange:)]) {
            [self.delegate rtmpConnect:self statedChange:stated];
        }
    });
}

- (BOOL)isConnected {
    return _stated == RTMPConnectStatedConnected;
}

- (BOOL)startWithUrl:(NSString *)url {
    if (!url || url.length < 8) {
        NSLog(@"rtmp url error");
        return NO;
    }
    if (rtmp != NULL) {
        NSLog(@"rtmp opend");
        return NO;
    }
    self.stated = RTMPConnectStatedConnecting;
    rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    rtmp->Link.timeout = 10;
    char *rtmpUrl = (char *)[url UTF8String];
    int ret = 0;
    ret = RTMP_SetupURL(rtmp, rtmpUrl);
    if (!ret) {
        RTMP_Free(rtmp);
        self.stated = RTMPConnectStatedConnectErr;
        return NO;
    };
    RTMP_EnableWrite(rtmp);
    RTMP_SetBufferMS(rtmp, 3 * 1000);
    ret = RTMP_Connect(rtmp, NULL);
    if (!ret) {
        NSLog(@"rtmp connect faild");
        RTMP_Free(rtmp);
        self.stated = RTMPConnectStatedConnectErr;
        return NO;
    }
    ret = RTMP_ConnectStream(rtmp, 0);
    if (!ret) {
        NSLog(@"rtmp stream faild");
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        self.stated = RTMPConnectStatedConnectErr;
        return NO;
    }
    NSLog(@"rtmp connect success");
    start_time = 0;
    self.stated = RTMPConnectStatedConnected;
    return YES;
}

- (void)stop {
    if (rtmp == NULL) {
        return;
    }
    self.stated = RTMPConnectStatedEnd;
    RTMP_Close(rtmp);
    RTMP_Free(rtmp);
    rtmp = NULL;
}

- (void)sendFrame:(FrameData *)frame {
    dispatch_async(self.connectQueue, ^{
        if ([frame isKindOfClass:[FrameVideoData class]]) {
            //发送视频
            FrameVideoData *videoFrame = (FrameVideoData *)frame;
            if (videoFrame.isSpsAndPps) {
                [self sendSpsData:videoFrame.spsData ppsData:videoFrame.ppsData];
            } else {
                [self sendVideoData:videoFrame];
            }
        } else {
            //发送音频
            FrameAudioData *audioFrame = (FrameAudioData *)frame;
            if (!self.sendHeader) {
                [self sendAudioHeader:audioFrame];
                self.sendHeader = YES;
            } else {
                [self sendAudioData:audioFrame];
            }
        }
    });
}

//video
- (void)sendSpsData:(NSData *)spsData ppsData:(NSData *)ppsData {
    unsigned char * body    =NULL;
    NSInteger iIndex        = 0;
    NSInteger rtmpLength    = 1024;
    const char *sps         = spsData.bytes;
    const char *pps         = ppsData.bytes;
    NSInteger sps_len       = spsData.length;
    NSInteger pps_len       = ppsData.length;

    body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);  // 函数常用于内存空间初始化 用来对一段内存空间全部设置为某个字符，一般用在对定义的字符串进行初始化为‘ ’或‘/0’

    body[iIndex++] = 0x17; //frame type

    body[iIndex++] = 0x00; //fixed 4字节
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;

    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;

    /*sps*/
    body[iIndex++]   = 0xe1;
    body[iIndex++] = (sps_len >> 8) & 0xff;
    body[iIndex++] = sps_len & 0xff;
    memcpy(&body[iIndex],sps,sps_len);  // 用来做内存拷贝，你可以拿它拷贝任何数据类型的对象，可以指定拷贝的数据长度
    iIndex += sps_len;

    /*pps*/
    body[iIndex++]   = 0x01;
    body[iIndex++] = (pps_len >> 8) & 0xff;
    body[iIndex++] = (pps_len) & 0xff;
    memcpy(&body[iIndex], pps, pps_len);
    iIndex +=  pps_len;

    /*调用发送接口*/
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    free(body);
}

- (void)sendVideoData:(FrameVideoData *)frame {
    if (frame.data.length < 11) {
        return;
    }
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length+9;
    unsigned char *body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);

    if(frame.isKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    } else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length ) & 0xff;
    memcpy(&body[i],frame.data.bytes,frame.data.length);

    if (start_time == 0) {
        start_time = CFAbsoluteTimeGetCurrent() * 1000;
//        start_time = [[NSDate date] timeIntervalSince1970] * 1000;
    }
//    uint64_t timestamp = [[NSDate date] timeIntervalSince1970] * 1000 - start_time;
    uint64_t timestamp = CFAbsoluteTimeGetCurrent() * 1000 - start_time;
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    NSLog(@"发送的当前视频时间戳=%lld",frame.timestamp);
    free(body);
}

//audio
- (void)sendAudioHeader:(FrameAudioData *)frame {
    if (!frame.info) {
        return;
    }
    NSInteger rtmpLength = frame.info.length + 2;/*spec data长度,一般是2*/
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);

    /*AF 00 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x00;
    memcpy(&body[2],frame.info.bytes,frame.info.length); /*spec_buf是AAC sequence header数据*/
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
    free(body);
}

- (void)sendAudioData:(FrameAudioData *)frame {
    if(!frame) return;
    NSInteger rtmpLength = frame.data.length + 2;/*spec data长度,一般是2*/
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);

    /*AF 01 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x01;
    memcpy(&body[2],frame.data.bytes,frame.data.length);
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:frame.timestamp];
    free(body);
    NSLog(@"发送的当前音频时间戳=%lld",frame.timestamp);
}

-(NSInteger) sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp{
    NSInteger rtmpLength = size;
    RTMPPacket rtmp_pack;   // 创建RTMP 包
    /*分配包内存和初始化*/
    RTMPPacket_Reset(&rtmp_pack);
    RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);

    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(rtmp) rtmp_pack.m_nInfoField2 = rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;

    NSInteger nRet;
    if (RTMP_IsConnected(rtmp)){
        int success = RTMP_SendPacket(rtmp,&rtmp_pack,0);    // true 为放进发送队列, false 不放进发送队列直接发送
//        NSLog(@"推流成功失败 %d", success);
//        NSLog(@"推流时间戳 %llu", nTimestamp);
        nRet = success;
    } else {
       nRet = -1;
    }
    RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (void)sendMetaData {
    RTMPPacket packet;

    if (RTMP_SendPacket(rtmp, &packet, 0) < 0) {
        RTMPPacket_Free(&packet);
        NSLog(@"发送元数据失败");
    }
}

@end
