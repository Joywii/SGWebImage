//
//  SGWebImageManager.m
//  sogoureader
//
//  Created by zhongweitao on 13-8-2.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import "SGWebImageManager.h"

static SGWebImageManager *instance;

@implementation SGWebImageManager

+ (id)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (instance == nil)
        {
            instance = [[SGWebImageManager alloc] init];
        }
    });
    return instance;
}
- (id)init
{
    if ((self = [super init]))
    {
        downloadDelegates = [[NSMutableArray alloc] init];
        downloaders = [[NSMutableArray alloc] init];
        cacheDelegates = [[NSMutableArray alloc] init];
        cacheURLs = [[NSMutableArray alloc] init];
        downloaderForURL = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc
{
    [downloadDelegates release];
    [downloaders release];
    [cacheDelegates release];
    [cacheURLs release];
    [downloaderForURL release];
    downloadDelegates = nil;
    downloaders = nil;
    cacheDelegates = nil;
    cacheURLs = nil;
    downloaderForURL = nil;
    [super dealloc];
}
- (void)downloadWithURL:(NSURL *)url delegate:(id<SGWebImageManagerDelegate>)delegate options:(SGWebImageOptions)options
{
    if ([url isKindOfClass:NSString.class])
    {
        url = [NSURL URLWithString:(NSString *)url];
    }
    if (!url || !delegate)
    {
        return;
    }
    [cacheDelegates addObject:delegate];
    [cacheURLs addObject:url];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys: delegate, @"delegate",url, @"url",[NSNumber numberWithInt:options], @"options",nil];
    [[SGWebImageCache sharedImageCache] imageFromKey:[url absoluteString] delegate:self userInfo:info];
}
- (void)cancelForDelegate:(id<SGWebImageManagerDelegate>)delegate
{
    NSUInteger idx;
    while ((idx = [cacheDelegates indexOfObjectIdenticalTo:delegate]) != NSNotFound)
    {
        [cacheDelegates removeObjectAtIndex:idx];
        [cacheURLs removeObjectAtIndex:idx];
    }
    
    while ((idx = [downloadDelegates indexOfObjectIdenticalTo:delegate]) != NSNotFound)
    {
        SGWebImageDownloader *downloader = [[downloaders objectAtIndex:idx] retain];
        
        [downloadDelegates removeObjectAtIndex:idx];
        [downloaders removeObjectAtIndex:idx];
        
        if (![downloaders containsObject:downloader])
        {
            // No more delegate are waiting for this download, cancel it
            [downloader cancel];
            [downloaderForURL removeObjectForKey:downloader.url];
        }
        [downloader release];
    }
}

#pragma SGWebImageCacheDelete
- (NSUInteger)indexOfDelegate:(id<SGWebImageManagerDelegate>)delegate waitingForURL:(NSURL *)url
{
    NSUInteger idx;
    for (idx = 0; idx < [cacheDelegates count]; idx++)
    {
        if ([cacheDelegates objectAtIndex:idx] == delegate && [[cacheURLs objectAtIndex:idx] isEqual:url])
        {
            return idx;
        }
    }
    return NSNotFound;
}
- (void)imageCache:(SGWebImageCache *)imageCache didFindImage:(UIImage *)image forKey:(NSString *)key userInfo:(NSDictionary *)info
{
    NSURL *url = [info objectForKey:@"url"];
    id<SGWebImageManagerDelegate> delegate = [info objectForKey:@"delegate"];
    
    NSUInteger idx = [self indexOfDelegate:delegate waitingForURL:url];
    if (idx == NSNotFound)
    {
        // Request has since been canceled
        return;
    }
    if ([delegate respondsToSelector:@selector(webImageManager:didFinishWithImage:)])
    {
        [delegate performSelector:@selector(webImageManager:didFinishWithImage:) withObject:self withObject:image];
    }
    [cacheDelegates removeObjectAtIndex:idx];
    [cacheURLs removeObjectAtIndex:idx];
}
- (void)imageCache:(SGWebImageCache *)imageCache didNotFindImageForKey:(NSString *)key userInfo:(NSDictionary *)info
{
    NSURL *url = [info objectForKey:@"url"];
    id<SGWebImageManagerDelegate> delegate = [info objectForKey:@"delegate"];
    SGWebImageOptions options = [[info objectForKey:@"options"] intValue];
    
    NSUInteger idx = [self indexOfDelegate:delegate waitingForURL:url];
    if (idx == NSNotFound)
    {
        // Request has since been canceled
        return;
    }
    
    [cacheDelegates removeObjectAtIndex:idx];
    [cacheURLs removeObjectAtIndex:idx];
    
    SGWebImageDownloader *downloader = [downloaderForURL objectForKey:url];
    if (!downloader)
    {
        downloader = [SGWebImageDownloader downloaderWithUrl:url delegate:self userInfo:info options:options];
        [downloaderForURL setObject:downloader forKey:url];
    }
    else
    {
        downloader.userInfo = info;
    }
    [downloadDelegates addObject:delegate];
    [downloaders addObject:downloader];
}
- (void)imageDownloader:(SGWebImageDownloader *)downloader didFinishWithImage:(UIImage *)image
{
    [downloader retain];
    SGWebImageOptions options = [[downloader.userInfo objectForKey:@"options"] intValue];
    
    // Notify all the downloadDelegates with this downloader
    for (NSInteger idx = (NSInteger)[downloaders count] - 1; idx >= 0; idx--)
    {
        NSUInteger uidx = (NSUInteger)idx;
        SGWebImageDownloader *aDownloader = [downloaders objectAtIndex:uidx];
        if (aDownloader == downloader)
        {
            id<SGWebImageManagerDelegate> delegate = [downloadDelegates objectAtIndex:uidx];
            [delegate retain];
            [delegate autorelease];
            
            if (image)
            {
                if ([delegate respondsToSelector:@selector(webImageManager:didFinishWithImage:)])
                {
                    [delegate performSelector:@selector(webImageManager:didFinishWithImage:) withObject:self withObject:image];
                }
            }
            else
            {
                if ([delegate respondsToSelector:@selector(webImageManager:didFailWithError:)])
                {
                    [delegate performSelector:@selector(webImageManager:didFailWithError:) withObject:self withObject:nil];
                }
            }
            
            [downloaders removeObjectAtIndex:uidx];
            [downloadDelegates removeObjectAtIndex:uidx];
        }
    }
    if (image)
    {
        // Store the image in the cache
        [[SGWebImageCache sharedImageCache] cacheImage:image withURL:[downloader.url absoluteString] options:options];
    }

    // Release the downloader
    [downloaderForURL removeObjectForKey:downloader.url];
    [downloader release];

}
- (void)imageDownloader:(SGWebImageDownloader *)downloader didFailWithError:(NSError *)error
{
    [downloader retain];
    
    // Notify all the downloadDelegates with this downloader
    for (NSInteger idx = (NSInteger)[downloaders count] - 1; idx >= 0; idx--)
    {
        NSUInteger uidx = (NSUInteger)idx;
        SGWebImageDownloader *aDownloader = [downloaders objectAtIndex:uidx];
        if (aDownloader == downloader)
        {
            id<SGWebImageManagerDelegate> delegate = [downloadDelegates objectAtIndex:uidx];
            [delegate retain];
            [delegate autorelease];
            
            if ([delegate respondsToSelector:@selector(webImageManager:didFailWithError:)])
            {
                [delegate performSelector:@selector(webImageManager:didFailWithError:) withObject:self withObject:error];
            }
            
            [downloaders removeObjectAtIndex:uidx];
            [downloadDelegates removeObjectAtIndex:uidx];
        }
    }
    
    // Release the downloader
    [downloaderForURL removeObjectForKey:downloader.url];
    [downloader release];

}
@end
