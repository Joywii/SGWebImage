//
//  SGURLCache.h
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

/*
 *NSURLCache默认情况下，内存是4M，4* 1024 * 1024；Disk为20M，20 * 1024 ＊ 1024；
 *实际情况是没有磁盘缓存 iOS5之前
 *路径在(NSHomeDirectory)/Library/Caches/(current application name, [[NSProcessInfo processInfo] processName])
 */

/*
 *使用方法：
 *SGURLCache *urlCache = [[[SGURLCache alloc] init] autorelease];
 *[NSURLCache setSharedURLCache:urlCache];
 */


#import <Foundation/Foundation.h>

@interface SGURLCache : NSURLCache
{

}

@end
