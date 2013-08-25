//
//  UIImageView+MyWebCache.m
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import "UIImageView+SGWebCache.h"
#import "SGWebImageCache.h"


@implementation UIImageView (SGWebCache)

- (void)setImageWithURL:(NSURL *)url holderImage:(UIImage *)holderImage options:(SGWebImageOptions)options
{
    SGWebImageManager *manager = [SGWebImageManager sharedManager];
    [manager cancelForDelegate:self];
    self.image = holderImage;
    if (url)
    {
        [manager downloadWithURL:url delegate:self options:options];
    }
}
- (void)webImageManager:(SGWebImageManager *)imageManager didFinishWithImage:(UIImage *)image
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.image = image;
    });
}
- (void)webImageManager:(SGWebImageManager *)imageManager didFailWithError:(NSError *)error
{
    
}
- (void)cacheImageToDiskWithKey:(NSString*)key
{
    [[SGWebImageCache sharedImageCache] cacheMemoryImageToDiskWithKey:key];
}
@end
