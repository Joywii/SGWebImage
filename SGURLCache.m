//
//  SGURLCache.m
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import "SGURLCache.h"
#import "SGWebImageCache.h"


@implementation SGURLCache

- (BOOL)isPicUrl:(NSString *)url;
{
    BOOL isPic = NO;
    NSRange range = [url rangeOfString:@"img.store.sogou.com"];
    if (range.location != NSNotFound)
    {
        isPic = YES;
    }
    return isPic;
}
-(NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest*)request
{
    NSURL* url = request.URL;
    if ([self isPicUrl:[url absoluteString]])
    {
        NSData *imageData = [[SGWebImageCache sharedImageCache] getImageDataWithKey:[url absoluteString]];
        if(imageData)
        {
            NSURLResponse* response = [[NSURLResponse alloc] initWithURL:url
                                                                MIMEType:@"image/jpeg"
                                                   expectedContentLength:[imageData length] textEncodingName:nil];
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:imageData userInfo:nil storagePolicy:NSURLCacheStorageAllowedInMemoryOnly];
            [response release];
            return [cachedResponse autorelease];
        }
        else
        {
            //NSLog(@"缓存中不存在！");
        }
	}
	NSCachedURLResponse *response = [super cachedResponseForRequest:request];
	return response;    
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    if(request.cachePolicy != NSURLRequestReloadIgnoringLocalCacheData && request.cachePolicy != NSURLRequestReloadIgnoringCacheData && request.cachePolicy != NSURLRequestReloadIgnoringLocalAndRemoteCacheData && [self isPicUrl:[request.URL absoluteString]])
    {
        //|| [cachedResponse.response.MIMEType isEqualToString:@"image/png"]
        if([cachedResponse.response.MIMEType isEqualToString:@"image/jpeg"] || [cachedResponse.response.MIMEType isEqualToString:@"image/bmp"])
        {
            //NSLog(@"缓存到本地 %@",request.URL);
            [[SGWebImageCache sharedImageCache] cacheToDiskWithImageData:cachedResponse.data withKey:[request.URL absoluteString]];
        }
    }
}

@end
