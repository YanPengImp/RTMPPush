//
//  FCImageFliter.m
//  FilterCamera
//
//  Created by Imp on 2018/8/10.
//  Copyright © 2018年 jingbo. All rights reserved.
//

#import "FCImageFliter.h"

#define kBitsPerComponent (8)
#define kBitsPerPixel (32)
#define kPixelChannelCount (4)

// 1、 lomo
float colormatrix_lomo[] = {
    1.20, 0.10, 0.10, 0.00, -73.10,
    0.00, 1.20, 0.10, 0.00, -73.10,
    0.00, 0.10, 1.10, 0.00, -73.10,
    0.00, 0.00, 0.00, 1.00, 0.00
};

// 2、黑白
float colormatrix_heibai[] = {
    0.00, 0.00, 1.00, 0.00, -1,
    0.00, 0.00, 1.00, 0.00, -1,
    0.00, 0.00, 1.00, 0.00, -1,
    0.00, 0.00, 0.00, 1.00, 0.00
};
// 3、复古
float colormatrix_huajiu[] = {
    0.2f,0.5f, 0.1f, 0, 40.8f,
    0.2f, 0.5f, 0.1f, 0, 40.8f,
    0.2f,0.5f, 0.1f, 0, 40.8f,
    0, 0, 0, 1, 0 };

// 4、哥特
float colormatrix_gete[] = {
    1.9f,-0.3f, -0.2f, 0,-87.0f,
    -0.2f, 1.7f, -0.1f, 0, -87.0f,
    -0.1f,-0.6f, 2.0f, 0, -87.0f,
    0, 0, 0, 1.0f, 0 };

// 5、锐化
float colormatrix_ruise[] = {
    4.8f,-1.0f, -0.1f, 0,-388.4f,
    -0.5f,4.4f, -0.1f, 0,-388.4f,
    -0.5f,-1.0f, 5.2f, 0,-388.4f,
    0, 0, 0, 1.0f, 0 };


// 6、淡雅
float colormatrix_danya[] = {
    0.6f,0.3f, 0.1f, 0,73.3f,
    0.2f,0.7f, 0.1f, 0,73.3f,
    0.2f,0.3f, 0.4f, 0,73.3f,
    0, 0, 0, 1.0f, 0 };

// 7、酒红
float colormatrix_jiuhong[] = {
    1.2f,0.0f, 0.0f, 0.0f,0.0f,
    0.0f,0.9f, 0.0f, 0.0f,0.0f,
    0.0f,0.0f, 0.8f, 0.0f,0.0f,
    0, 0, 0, 1.0f, 0 };

// 8、清宁
float colormatrix_qingning[] = {
    0.9f, 0, 0, 0, 0,
    0, 1.1f,0, 0, 0,
    0, 0, 0.9f, 0, 0,
    0, 0, 0, 1.0f, 0 };

// 9、浪漫
float colormatrix_langman[] = {
    0.9f, 0, 0, 0, 63.0f,
    0, 0.9f,0, 0, 63.0f,
    0, 0, 0.9f, 0, 63.0f,
    0, 0, 0, 1.0f, 0 };

// 10、光晕
float colormatrix_guangyun[] = {
    0.9f, 0, 0,  0, 64.9f,
    0, 0.9f,0,  0, 64.9f,
    0, 0, 0.9f,  0, 64.9f,
    0, 0, 0, 1.0f, 0 };

// 11、蓝调
float colormatrix_landiao[] = {
    2.1f, -1.4f, 0.6f, 0.0f, -31.0f,
    -0.3f, 2.0f, -0.3f, 0.0f, -31.0f,
    -1.1f, -0.2f, 2.6f, 0.0f, -31.0f,
    0.0f, 0.0f, 0.0f, 1.0f, 0.0f
};

//12、反色
float colormatrix_fanse[] = {
    -1  ,0   ,0    ,0   ,255,
    0   ,-1  ,0    ,0   ,255,
    0   ,0   ,-1   ,0   ,255,
    0   ,0   ,0    ,1   ,0
};

@implementation FCImageFliter

+ (UIImage *)dealCGImage:(CGImageRef)img fliterType:(FCImageFliterType )type {
    if (type == FCImageFliterTypeLemo) {
        return [self dealCGImage:img matrix:colormatrix_lomo];
    } else if (type == FCImageFliterTypeHeibai) {
        return [self dealCGImage:img matrix:colormatrix_heibai];
    } else if (type == FCImageFliterTypeFugu) {
        return [self dealCGImage:img matrix:colormatrix_huajiu];
    } else if (type == FCImageFliterTypeGete) {
        return [self dealCGImage:img matrix:colormatrix_gete];
    } else if (type == FCImageFliterTypeRuise) {
        return [self dealCGImage:img matrix:colormatrix_ruise];
    } else if (type == FCImageFliterTypeDanya) {
        return [self dealCGImage:img matrix:colormatrix_danya];
    } else if (type == FCImageFliterTypeJiuhong) {
        return [self dealCGImage:img matrix:colormatrix_jiuhong];
    } else if (type == FCImageFliterTypeQingning) {
        return [self dealCGImage:img matrix:colormatrix_qingning];
    } else if (type == FCImageFliterTypeLangman) {
        return [self dealCGImage:img matrix:colormatrix_langman];
    } else if (type == FCImageFliterTypeGuangyun) {
        return [self dealCGImage:img matrix:colormatrix_guangyun];
    } else if (type == FCImageFliterTypeLandiao) {
        return [self dealCGImage:img matrix:colormatrix_landiao];
    } else if (type == FCImageFliterTypeFanse) {
        return [self dealCGImage:img matrix:colormatrix_fanse];
    } else {
        return nil;
    }
}

+ (UIImage *)dealImage:(UIImage *)img fliterType:(FCImageFliterType)type {
    if (type == FCImageFliterTypeLemo) {
        return [self dealImage:img matrix:colormatrix_lomo];
    } else if (type == FCImageFliterTypeHeibai) {
        return [self dealImage:img matrix:colormatrix_heibai];
    } else if (type == FCImageFliterTypeFugu) {
        return [self dealImage:img matrix:colormatrix_huajiu];
    } else if (type == FCImageFliterTypeGete) {
        return [self dealImage:img matrix:colormatrix_gete];
    } else if (type == FCImageFliterTypeRuise) {
        return [self dealImage:img matrix:colormatrix_ruise];
    } else if (type == FCImageFliterTypeDanya) {
        return [self dealImage:img matrix:colormatrix_danya];
    } else if (type == FCImageFliterTypeJiuhong) {
        return [self dealImage:img matrix:colormatrix_jiuhong];
    } else if (type == FCImageFliterTypeQingning) {
        return [self dealImage:img matrix:colormatrix_qingning];
    } else if (type == FCImageFliterTypeLangman) {
        return [self dealImage:img matrix:colormatrix_langman];
    } else if (type == FCImageFliterTypeGuangyun) {
        return [self dealImage:img matrix:colormatrix_guangyun];
    } else if (type == FCImageFliterTypeLandiao) {
        return [self dealImage:img matrix:colormatrix_landiao];
    } else if (type == FCImageFliterTypeFanse) {
        return [self dealImage:img matrix:colormatrix_fanse];
    } else {
        return img;
    }
}

+ (UIImage *)dealImage:(UIImage *)img matrix:(float *)matrix{
    return [self dealCGImage:img.CGImage matrix:matrix];
}

+ (UIImage *)dealCGImage:(CGImageRef)img matrix:(float *)matrix {
    // 1.CGDataProviderRef 把 CGImage 转 二进制流
    CGDataProviderRef provider = CGImageGetDataProvider(img);
    void *imgData = (void *)CFDataGetBytePtr(CGDataProviderCopyData(provider));
    int width = CGImageGetWidth(img);
    int height = CGImageGetHeight(img);

    // 2.处理 imgData
    //    dealImageInverse(imgData, width, height);//反色
    //    dealImageMosaic(imgData,width,height,15);//马赛克

    dealImageFilter(imgData, width, height, matrix);

    // 3.CGDataProviderRef 把 二进制流 转 CGImage
    CGDataProviderRef pv = CGDataProviderCreateWithData(NULL, imgData, width * height * kPixelChannelCount, releaseData);
    CGImageRef content = CGImageCreate(width , height, kBitsPerComponent, kBitsPerPixel, kPixelChannelCount * width, CGColorSpaceCreateDeviceRGB(), kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, pv, NULL, true, kCGRenderingIntentDefault);
    UIImage *result = [UIImage imageWithCGImage:content];
    CGDataProviderRelease(pv);
    CGImageRelease(content);

    return result;
}

void releaseData(void *info, const void *data, size_t size) {
    free((void *)data);
}

//颜色矩阵滤镜
void dealImageFilter(UInt32 *img,int w,int h,const float *matrix) {
//    dealImageInverse(img, w, h);
//    return;
    UInt8 *cur = (UInt8 *)img;
    for (int i=0; i< w * h; i++, cur+=kPixelChannelCount) {
        int red = cur[0];
        int green = cur[1];
        int blue = cur[2];
        int alpha = cur[3];
        changeRGBA(&red, &green, &blue, &alpha, matrix);
        cur[0] = red;
        cur[1] = green;
        cur[2] = blue;
        cur[3] = alpha;
    }
}

static void changeRGBA(int *red,int *green,int *blue, int *alpha,const float *matrix) {
    float r = *red;
    float g = *green;
    float b = *blue;
    float a = *alpha;
    *red   = matrix[0] *r + matrix[1] *g + matrix[2] *b + matrix[3] *a + matrix[4];
    *green = matrix[5] *r + matrix[6] *g + matrix[7] *b + matrix[8] *a + matrix[9];
    *blue  = matrix[10]*r + matrix[11]*g + matrix[12]*b + matrix[13]*a + matrix[14];
    *alpha = matrix[15]*r + matrix[16]*g + matrix[17]*b + matrix[18]*a + matrix[19];
    *red > 255 ? *red = 255 :NO;
    *green > 255 ? *green = 255 :NO;
    *blue > 255 ? *blue = 255 :NO;
    *alpha > 255 ? *alpha = 255 :NO;
    *red < 0 ? *red = 0 : NO;
    *green < 0 ? *green = 0 : NO;
    *blue < 0 ? *blue = 0 : NO;
    *alpha < 0 ? *alpha = 0 : NO;
}

#pragma mark 另外的不通过颜色矩阵来处理

//马赛克处理 level->像素格子数
void dealImageMosaic(UInt32 *image,int width, int height, int level) {
    unsigned char *pixel[4] = {0};
    UInt8 *img = (UInt8 *)image;
    NSUInteger index,preIndex;
    for (NSUInteger i = 0; i < height - 1 ; i++) {
        for (NSUInteger j = 0; j < width - 1; j++) {
            index = i * width + j;
            if (i % level == 0) {
                if (j % level == 0) {
                    UInt8 *p = img + kPixelChannelCount*index;
                    memcpy(pixel, p, kPixelChannelCount);
                }else{
                    UInt8 *p = img + kPixelChannelCount*index;
                    memcpy(p, pixel, kPixelChannelCount);
                }
            } else {
                preIndex = (i-1)*width +j;
                memcpy(img + kPixelChannelCount*index, img + kPixelChannelCount*preIndex, kPixelChannelCount);
            }
        }
    }
}

//取反色
void dealImageInverse(UInt32 *img, int w, int h) {
    UInt32 *cur = img;
    for (int i=0; i< w * h; i++, cur++) {
        UInt8 *p = (UInt8 *)cur;
        // RGBA 排列取反色
        p[0] = 255 - p[0];
        p[1] = 255 - p[1];
        p[2] = 255 - p[2];
        p[3] = 255;
    }
}

@end
