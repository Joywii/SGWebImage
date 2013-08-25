//
//  UIImageView+MyWebCache.h
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SGWebImageCache.h"
#import "SGWebImageDownloader.h"
#import "SGWebImageManager.h"

@interface UIImageView (SGWebCache) <SGWebImageManagerDelegate>

- (void)setImageWithURL:(NSURL *)url holderImage:(UIImage *)holderImage options:(SGWebImageOptions)options;
- (void)cacheImageToDiskWithKey:(NSString*)key;
@end
