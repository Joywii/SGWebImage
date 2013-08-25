//
//  SGWebImageDownloader.h
//  sogoureader
//
//  Created by sogou on 13-8-1.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SGWebImageCache.h"


@class SGWebImageDownloader;

@protocol SGWebImageDownloaderDelegate <NSObject>

@optional

- (void)imageDownloader:(SGWebImageDownloader *)downloader didFinishWithImage:(UIImage *)image;
- (void)imageDownloader:(SGWebImageDownloader *)downloader didFailWithError:(NSError *)error;

@end

@interface SGWebImageDownloader : NSObject 
{
    NSURL *url;
    NSURLConnection *connection;
    NSMutableData *imageData;
    id userInfo;

    NSUInteger expectedSize;
}

@property (nonatomic, retain) NSURL *url;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *imageData;
@property (nonatomic, retain) id userInfo;
@property (nonatomic, assign) id<SGWebImageDownloaderDelegate> delegate;

- (void)cancel;
+ (id)downloaderWithUrl:(NSURL *)url delegate:(id<SGWebImageDownloaderDelegate>)delegate userInfo:(id)userInfo options:(SGWebImageOptions)options;
@end
