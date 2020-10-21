//
//  AudioEncoder.m
//  FilterCamera
//
//  Created by Imp on 2020/10/20.
//  Copyright © 2020 jingbo. All rights reserved.
//

#import "AudioEncoder.h"

@interface AudioEncoder ()

@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@property (nonatomic) char *pcmBuffer;
@property (nonatomic) size_t pcmBufferSize;

@end

@implementation AudioEncoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        _encoderQueue = dispatch_queue_create("aac.encoder.queue", DISPATCH_QUEUE_SERIAL);
        _audioConverter = NULL;
        _pcmBufferSize = 0;
        _aacBufferSize = 1024;
        _pcmBuffer = NULL;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
    }
    return self;
}

- (void)openEncoder:(CMSampleBufferRef)sampleBuffer {
    if (_audioConverter) {
        return;
    }
    AudioStreamBasicDescription inAudioStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
    inAudioStreamBasicDescription.mSampleRate = 44100;

    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate; // 音频流，在正常播放情况下的帧率。如果是压缩的格式，这个属性表示解压缩后的帧率。帧率不能为0。
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC; // 设置编码格式
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC; // 无损编码 ，0表示没有
    outAudioStreamBasicDescription.mBytesPerPacket = 0; // 每一个packet的音频数据大小。如果的动态大小，设置为0。动态大小的格式，需要用AudioStreamPacketDescription 来确定每个packet的大小。
    outAudioStreamBasicDescription.mFramesPerPacket = 1024; // 每个packet的帧数。如果是未压缩的音频数据，值是1。动态帧率格式，这个值是一个较大的固定数字，比如说AAC的1024。如果是动态大小帧数（比如Ogg格式）设置为0。
    outAudioStreamBasicDescription.mBytesPerFrame = 0; //  每帧的大小。每一帧的起始点到下一帧的起始点。如果是压缩格式，设置为0 。
    outAudioStreamBasicDescription.mChannelsPerFrame = 1; // 声道数
    outAudioStreamBasicDescription.mBitsPerChannel = 0; // 压缩格式设置为0
    outAudioStreamBasicDescription.mReserved = 0; // 8字节对齐，填0.
    AudioClassDescription *desc = [self getDesWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, desc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"create audioConverter faild %d", status);
    }
}

- (AudioClassDescription *)getDesWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer {
    static AudioClassDescription desc;
    UInt32 encoderSpecifier = type;
    OSStatus st;
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }

    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }

    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    return nil;
}

/**
 *  填充PCM到缓冲区
 */
- (size_t) copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    size_t originalBufferSize = _pcmBufferSize;
    if (!originalBufferSize) {
        return 0;
    }
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = (int)_pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    return originalBufferSize;
}

OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AudioEncoder *encoder = (__bridge AudioEncoder *)(inUserData);
    UInt32 requestedPackets = *ioNumberDataPackets;

    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPackets) {
        //PCM 缓冲区还没满
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;

    return noErr;
}


- (void)encodeAudio:(CMSampleBufferRef)sampleBuffer timestamp:(uint64_t)timestamp{
    CFRetain(sampleBuffer);
    dispatch_async(_encoderQueue, ^{
        [self openEncoder:sampleBuffer];
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CFRetain(blockBuffer);
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &self->_pcmBufferSize, &self->_pcmBuffer);
        NSError *error = nil;
        if (status != kCMBlockBufferNoErr) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        memset(self->_aacBuffer, 0, self->_aacBufferSize);

        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = 1;
        outAudioBufferList.mBuffers[0].mDataByteSize = (int)self->_aacBufferSize;
        outAudioBufferList.mBuffers[0].mData = self->_aacBuffer;
        AudioStreamPacketDescription *outPacketDescription = NULL;
        UInt32 ioOutputDataPacketSize = 1;
        // Converts data supplied by an input callback function, supporting non-interleaved and packetized formats.
        // Produces a buffer list of output data from an AudioConverter. The supplied input callback function is called whenever necessary.
        status = AudioConverterFillComplexBuffer(self->_audioConverter, inInputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &outAudioBufferList, outPacketDescription);
        NSData *data = nil;
        if (status == 0) {
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
            NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
            [fullData appendData:rawAAC];
            data = fullData;
        } else {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }

        FrameAudioData *audioFrame = [[FrameAudioData alloc] init];
        audioFrame.timestamp = timestamp;
        audioFrame.data      = [NSData dataWithBytes:self->_aacBuffer length:outAudioBufferList.mBuffers[0].mDataByteSize];

        // flv编码音频头 44100 为0x12 0x10
        char *asc = malloc(2);  // 开辟两个长度的字节
        asc[0] = 0x10 | ((4>>1) & 0x3);
        asc[1] = ((4 & 0x1)<<7) | ((1 & 0xF) << 3);
        audioFrame.info =  [NSData dataWithBytes:asc length:2];

        if (self.delegate && [self.delegate respondsToSelector:@selector(encodeAudioFrameData:)]) {
            [self.delegate encodeAudioFrameData:audioFrame];
        }

        if (asc) free(asc);     // 释放
        CFRelease(sampleBuffer);
        CFRelease(blockBuffer);
    });
}

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

- (void)endEncode {

}

@end
