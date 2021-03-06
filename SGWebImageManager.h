//
//  SGWebImageManager.h
//  sogoureader
//
//  Created by zhongweitao on 13-8-2.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SGWebImageDownloader.h"
#import "SGWebImageCache.h"

@class SGWebImageManager;

@protocol SGWebImageManagerDelegate <NSObject>

@optional
- (void)webImageManager:(SGWebImageManager *)imageManager didFinishWithImage:(UIImage *)image;
- (void)webImageManager:(SGWebImageManager *)imageManager didFailWithError:(NSError *)error;
@end

@interface SGWebImageManager : NSObject <SGImageCacheDelegate,SGWebImageDownloaderDelegate>
{
    NSMutableArray *downloadDelegates;
    NSMutableArray *downloaders;
    NSMutableArray *cacheDelegates;
    NSMutableArray *cacheURLs;
    NSMutableDictionary *downloaderForURL;
}

+ (id)sharedManager;
- (void)cancelForDelegate:(id<SGWebImageManagerDelegate>)delegate;
- (void)downloadWithURL:(NSURL *)url delegate:(id<SGWebImageManagerDelegate>)delegate options:(SGWebImageOptions)options;
@end
