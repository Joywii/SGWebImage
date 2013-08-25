//
//  SGWebImageDecoder.h
//  sogoureader
//
//  Created by zhongweitao on 13-8-5.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SGWebImageDecoderDelegate;

@interface SGWebImageDecoder : NSObject
{
    NSOperationQueue *imageDecodingQueue;
}


+ (SGWebImageDecoder *)sharedImageDecoder;
- (void)decodeImage:(UIImage *)image withDelegate:(id <SGWebImageDecoderDelegate>)delegate userInfo:(NSDictionary *)info;

@end

@protocol SGWebImageDecoderDelegate <NSObject>

- (void)imageDecoder:(SGWebImageDecoder *)decoder didFinishDecodingImage:(UIImage *)image userInfo:(NSDictionary *)userInfo;

@end

@interface UIImage (ForceDecode)

+ (UIImage *)decodedImageWithImage:(UIImage *)image;

@end

