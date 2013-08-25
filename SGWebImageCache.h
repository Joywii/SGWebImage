//
//  MyWebImageManager.h
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+MD5.h"

typedef enum
{
    SGWebImageCacheMemoryOnly = 1 << 0,
    SGWebImageCacheMemoryAndDisk = 1 << 1
} SGWebImageOptions;

@class SGWebImageCache;

@protocol SGImageCacheDelegate <NSObject>

@optional
- (void)imageCache:(SGWebImageCache *)imageCache didFindImage:(UIImage *)image forKey:(NSString *)key userInfo:(NSDictionary *)info;
- (void)imageCache:(SGWebImageCache *)imageCache didNotFindImageForKey:(NSString *)key userInfo:(NSDictionary *)info;

@end


@interface SGWebImageCache : NSObject
{
//    NSMutableDictionary *onlyMemoryCache;
//    NSMutableDictionary *diskMemoryCache;
    NSCache *onlyMemoryCache;
    NSCache *diskMemoryCache;
    NSString *diskCachePath;
    NSString *diskMemoryCachePath;
    NSOperationQueue *cacheInQueue;
    NSOperationQueue *cacheOutQueue;
}

+ (id)sharedImageCache;
- (void)imageFromKey:(NSString *)key delegate:(id <SGImageCacheDelegate>)delegate userInfo:(NSDictionary *)info;

- (void)cacheMemoryImageToDiskWithKey:(NSString *)key;
- (void)asyncCacheMemoryImageToDiskWithKey:(NSString *)key;
- (void)cacheImage:(UIImage *)image withURL:(NSString *)URL options:(SGWebImageOptions)options;

- (void)clearOnlyMemory;
- (void)clearDiskMemory;

- (void)clearMemoryDisk;
- (void)clearMemoryDiskAsync;
- (void)cleanMemoryDiskTimeOut;

- (void)clearDisk;
- (void)clearDiskAsync;

- (void)cacheToDiskWithImageData:(NSData *)imageData withKey:(NSString *)key;
- (NSData *)getImageDataWithKey:(NSString *)key;
@end
