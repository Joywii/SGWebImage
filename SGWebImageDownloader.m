//
//  SGWebImageDownloader.m
//  sogoureader
//
//  Created by sogou on 13-8-1.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import "SGWebImageDownloader.h"
#import <ImageIO/ImageIO.h>


@implementation SGWebImageDownloader

@synthesize delegate = _delegate;
@synthesize url;
@synthesize connection;
@synthesize imageData;
@synthesize userInfo;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [url release];
    url = nil;
    [connection release];
    connection = nil;
    [imageData release];
    imageData = nil;
    [userInfo release];
    userInfo = nil;
    [super dealloc];
}

+ (id)downloaderWithUrl:(NSURL *)url delegate:(id<SGWebImageDownloaderDelegate>)aDelegate userInfo:(id)userInfo options:(SGWebImageOptions)options
{
    SGWebImageDownloader *downloader = [[[SGWebImageDownloader alloc] init] autorelease];
    downloader.url = url;
    downloader.delegate = aDelegate;
    downloader.userInfo = userInfo;
    [downloader performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
    return downloader;
}
- (void)start
{
    // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO] autorelease];
    
//    // If not in low priority mode, ensure we aren't blocked by UI manipulations (default runloop mode for NSURLConnection is NSEventTrackingRunLoopMode)
//    if (!lowPriority)
//    {
//        [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
//    }
    [connection start];
    [request release];
    request = nil;
    
    if (connection)
    {
    }
    else
    {
        if ([_delegate respondsToSelector:@selector(imageDownloader:didFailWithError:)])
        {
            [_delegate performSelector:@selector(imageDownloader:didFailWithError:) withObject:self withObject:nil];
        }
    }
}

- (void)cancel
{
    if (connection)
    {
        [connection cancel];
        self.connection = nil;
    }
}

#pragma mark NSURLConnection (delegate)

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)response
{
    if (![response respondsToSelector:@selector(statusCode)] || [((NSHTTPURLResponse *)response) statusCode] < 400)
    {
        expectedSize = response.expectedContentLength > 0 ? (NSUInteger)response.expectedContentLength : 0;
        self.imageData = [[[NSMutableData alloc] initWithCapacity:expectedSize] autorelease];
    }
    else
    {
        [aConnection cancel];
        if ([_delegate respondsToSelector:@selector(imageDownloader:didFailWithError:)])
        {
            NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain
                                                        code:[((NSHTTPURLResponse *)response) statusCode]
                                                    userInfo:nil];
            [_delegate performSelector:@selector(imageDownloader:didFailWithError:) withObject:self withObject:error];
            [error release];
        }
        
        self.connection = nil;
        self.imageData = nil;
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
    [imageData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    self.connection = nil;

    if ([_delegate respondsToSelector:@selector(imageDownloader:didFinishWithImage:)])
    {
        UIImage *image = [[[UIImage alloc] initWithData:imageData] autorelease];
        if (image)
        {
            //[[SGWebImageDecoder sharedImageDecoder] decodeImage:image withDelegate:self userInfo:nil];
            [_delegate performSelector:@selector(imageDownloader:didFinishWithImage:) withObject:self withObject:image];
        }
        else
        {
            //图片大小为空
            [_delegate performSelector:@selector(imageDownloader:didFailWithError:) withObject:self withObject:nil];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{    
    if ([_delegate respondsToSelector:@selector(imageDownloader:didFailWithError:)])
    {
        [_delegate performSelector:@selector(imageDownloader:didFailWithError:) withObject:self withObject:error];
    }
    self.connection = nil;
    self.imageData = nil;
}
//#pragma mark SDWebImageDecoderDelegate
//- (void)imageDecoder:(SGWebImageDecoder *)decoder didFinishDecodingImage:(UIImage *)image userInfo:(NSDictionary *)aUserInfo
//{
//    [_delegate performSelector:@selector(imageDownloader:didFinishWithImage:) withObject:self withObject:image];
//}
@end
