//
//  MyWebImageManager.m
//  sogoureader
//
//  Created by zhongweitao on 13-7-31.
//  Copyright (c) 2013年 sg. All rights reserved.
//

static NSInteger cacheMaxCacheAge = 60*60*24*7; // 暂定一周删除暂时缓存在本地图片

#import "SGWebImageCache.h"

static SGWebImageCache *instance;

@implementation SGWebImageCache

+ (id)sharedImageCache
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (instance == nil)
        {
            instance = [[SGWebImageCache alloc] init];
        }
    });
    return instance;
}
- (void)dealloc
{
    [onlyMemoryCache release], onlyMemoryCache = nil;
    [diskMemoryCache release], diskMemoryCache = nil;
    [diskCachePath release], diskCachePath = nil;
    [diskMemoryCachePath release], diskMemoryCachePath = nil;
    [cacheInQueue release];
    [cacheOutQueue release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}
- (id)init
{
    self = [super init];
    if (nil == instance)
    {
        onlyMemoryCache = [[NSCache alloc] init];
        onlyMemoryCache.name = [NSString stringWithFormat:@"sogoureader.tempImageCache"];
        [onlyMemoryCache setCountLimit:50];
        diskMemoryCache = [[NSCache alloc] init];
        diskMemoryCache.name = [NSString stringWithFormat:@"sogoureader.diskImageCache"];
        [diskMemoryCache setCountLimit:50];
        
        cacheInQueue = [[NSOperationQueue alloc] init];
        cacheInQueue.maxConcurrentOperationCount = 1;
        cacheOutQueue = [[NSOperationQueue alloc] init];
        cacheOutQueue.maxConcurrentOperationCount = 1;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        diskCachePath = [[[paths objectAtIndex:0] stringByAppendingPathComponent:@"ImageCache"] retain];
        diskMemoryCachePath = [[[paths objectAtIndex:0] stringByAppendingPathComponent:@"ImageMemoryCache"] retain];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:diskCachePath])
        {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:diskMemoryCachePath])
        {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:diskMemoryCachePath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanMemoryDiskTimeOut)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        instance = self;
    }
    return instance;
}
- (void)clearMemory
{
    [cacheInQueue cancelAllOperations];
    [self clearOnlyMemory];
    [self clearDiskMemory];
}
- (void)clearOnlyMemory
{
    [cacheInQueue cancelAllOperations];
    [onlyMemoryCache removeAllObjects];
}
- (void)clearDiskMemory
{
    [cacheInQueue cancelAllOperations];
    [diskMemoryCache removeAllObjects];
}
- (void)clearMemoryDisk
{
    [cacheInQueue cancelAllOperations];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:diskMemoryCachePath error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:diskMemoryCachePath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
}
- (void)cleanMemoryDiskTimeOut
{
    NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-cacheMaxCacheAge];
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:diskMemoryCachePath];
    for (NSString *fileName in fileEnumerator)
    {
        NSString *filePath = [diskMemoryCachePath stringByAppendingPathComponent:fileName];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        if ([[[attrs fileModificationDate] laterDate:expirationDate] isEqualToDate:expirationDate])
        {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
}
- (void)clearMemoryDiskAsync
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self clearMemoryDisk];
    });
}
- (void)clearDisk
{
    [cacheInQueue cancelAllOperations];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:diskCachePath error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
}
- (void)clearDiskAsync
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self clearDisk];
    });
}
- (void)notifyDelegate:(NSDictionary *)arguments
{
    NSString *key = [arguments objectForKey:@"key"];
    id <SGImageCacheDelegate> delegate = [arguments objectForKey:@"delegate"];
    NSDictionary *info = [arguments objectForKey:@"info"];
    UIImage *image = [arguments objectForKey:@"image"];
    
    if (image)
    {        
        if ([delegate respondsToSelector:@selector(imageCache:didFindImage:forKey:userInfo:)])
        {
            [delegate imageCache:self didFindImage:image forKey:key userInfo:info];
        }
    }
    else
    {
        if ([delegate respondsToSelector:@selector(imageCache:didNotFindImageForKey:userInfo:)])
        {
            [delegate imageCache:self didNotFindImageForKey:key userInfo:info];
        }
    }
}

- (void)imageFromKey:(NSString *)key delegate:(id <SGImageCacheDelegate>)delegate userInfo:(NSDictionary *)info
{
    NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithCapacity:4];
    [arguments setObject:key forKey:@"key"];
    [arguments setObject:delegate forKey:@"delegate"];
    [arguments setObject:info forKey:@"info"];
    
    SGWebImageOptions options = (SGWebImageOptions)[[info objectForKey:@"options"] integerValue];
    UIImage *image;
    //先判断onlyMemoryCache，没有的话再判断diskMemoryCache
    if(options == SGWebImageCacheMemoryOnly)
    {
        if([onlyMemoryCache objectForKey:key])
        {
            image = [onlyMemoryCache objectForKey:key];
            if(image)
            {
                [arguments setObject:image forKey:@"image"];
            }
            [self notifyDelegate:arguments];
            return;
        }
        else
        {
            if ([diskMemoryCache objectForKey:key])
            {
                image = [diskMemoryCache objectForKey:key];
                if(image)
                {
                    [arguments setObject:image forKey:@"image"];
                }
                [self notifyDelegate:arguments];
                return;
            }
            else
            {
                image = nil;
            }
        }
    }
    //先判断diskMemoryCache，没有的话再判断onlyMemoryCache
    else if(options == SGWebImageCacheMemoryAndDisk)
    {
        if ([diskMemoryCache objectForKey:key])
        {
            image = [diskMemoryCache objectForKey:key];
            if(image)
            {
                [arguments setObject:image forKey:@"image"];
            }
            [self notifyDelegate:arguments];
            return;
        }
        else
        {
            if ([onlyMemoryCache objectForKey:key])
            {
                image = [onlyMemoryCache objectForKey:key];
                //自动进行转存
                [self cacheToDiskWithImage:image withKey:key];
                //自动进行转存
                if(image)
                {
                    [diskMemoryCache setObject:image forKey:key];
                    [arguments setObject:image forKey:@"image"];
                }
                [self notifyDelegate:arguments];
                return;
            }
            else
            {
                image = nil;
            }
        }
    }
    else
    {
        image = nil;
    }
    //在内存中都没有的话，都进行本地磁盘查询
    if (image)
    {
    }
    else
    {
        NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                                 selector:@selector(queryDiskCache:)
                                                                                   object:arguments] autorelease];
        [cacheOutQueue addOperation:operation];
    }
}
- (void)queryDiskCache:(NSDictionary *)arguments
{
    NSString *key = [arguments objectForKey:@"key"];
    NSMutableDictionary *mutableArguments = [[arguments mutableCopy] autorelease];
    
    NSDictionary *info = [arguments objectForKey:@"info"];
    SGWebImageOptions options = (SGWebImageOptions)[[info objectForKey:@"options"] integerValue];
    
    NSString *localPath;
    //先判断diskMemoryCachePath，后判断diskCachePath
    if (options == SGWebImageCacheMemoryOnly)
    {
        localPath = [diskMemoryCachePath stringByAppendingPathComponent:[key md5]];
        UIImage *image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
        if (image != nil)
        {
            [onlyMemoryCache setObject:image forKey:key];
            [mutableArguments setObject:image forKey:@"image"];
        }
        else
        {
            localPath = [diskCachePath stringByAppendingPathComponent:[key md5]];
            image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
            if (image != nil)
            {
                [diskMemoryCache setObject:image forKey:key];
                [mutableArguments setObject:image forKey:@"image"];
            }
        }
    }
    //先判断diskCachePath,在判断diskMemoryCachePath
    else if(options == SGWebImageCacheMemoryAndDisk)
    {
        localPath = [diskCachePath stringByAppendingPathComponent:[key md5]];
        UIImage *image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
        if (image != nil)
        {
            [diskMemoryCache setObject:image forKey:key];
            [mutableArguments setObject:image forKey:@"image"];
        }
        else
        {
            localPath = [diskMemoryCachePath stringByAppendingPathComponent:[key md5]];
            image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
            //自动进行转存
            [self cacheToDiskWithImage:image withKey:key];
            //自动进行转存
            if (image != nil)
            {
                [diskMemoryCache setObject:image forKey:key];
                [mutableArguments setObject:image forKey:@"image"];
            }
        }
    }
    else
    {
        localPath = nil;
    }
//    NSString *localPath = [diskCachePath stringByAppendingPathComponent:[key md5]];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
//    {
//        return ;
//    }
    [self performSelectorOnMainThread:@selector(notifyDelegate:) withObject:mutableArguments waitUntilDone:NO];
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)cacheToDiskWithImage:(UIImage *)image withKey:(NSString *)key
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",key,@"url" ,nil];
    NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                             selector:@selector(cacheImageToDisk:)
                                                                               object:info] autorelease];
    [cacheInQueue addOperation:operation];
}
- (void)asyncCacheMemoryImageToDiskWithKey:(NSString *)key
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self cacheMemoryImageToDiskWithKey:key];
    });
}
- (void)cacheMemoryImageToDiskWithKey:(NSString *)key
{
    if ([onlyMemoryCache objectForKey:key])
    {
        UIImage *image = [onlyMemoryCache objectForKey:key];
        [diskMemoryCache setObject:image forKey:key];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",key,@"url" ,nil];
        [self cacheImageToDisk:info];//存到本地永久缓存
        [onlyMemoryCache removeObjectForKey:key];
    }
    else
    {
        //如果内存中没有存储，而本地暂时存储有，获取图片存到永久本地缓存和内存缓存。
        NSString *localPath = [diskMemoryCachePath stringByAppendingPathComponent:[key md5]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
        {
            UIImage *image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
            [diskMemoryCache setObject:image forKey:key];
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",key,@"url" ,nil];
            [self cacheImageToDisk:info];//存到不可删除缓存行列
        }
    }
    //本地的暂时缓存先不删除，过期后自动删除
//    NSString *localPath = [diskMemoryCachePath stringByAppendingPathComponent:[key md5]];
//    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
//    {
//        [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
//    }
}
- (void)cacheImage:(UIImage *)image withURL:(NSString *)URL options:(SGWebImageOptions)options
{
    if(options == SGWebImageCacheMemoryOnly)
    {
        [onlyMemoryCache setObject:image forKey:URL];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",URL,@"url" ,nil];
        //[self cacheImageToMemoryDisk:info];
        NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                                 selector:@selector(cacheImageToMemoryDisk:)
                                                                                   object:info] autorelease];
        [cacheInQueue addOperation:operation];
    }
    else if(options == SGWebImageCacheMemoryAndDisk)
    {
        [diskMemoryCache setObject:image forKey:URL];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",URL,@"url" ,nil];
        //[self cacheImageToDisk:info];
        NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                                 selector:@selector(cacheImageToDisk:)
                                                                                   object:info] autorelease];
        [cacheInQueue addOperation:operation];
    }
}
- (void)cacheImageToMemoryDisk:(NSDictionary *)info
{
    NSString *URL = [info objectForKey:@"url"];
    UIImage *image = [info objectForKey:@"image"];
    
    NSString *localPath = [diskMemoryCachePath stringByAppendingPathComponent:[URL md5]];
    NSData *localData = UIImageJPEGRepresentation(image, 1.0f);
    
    if ([localData length] <= 1)
    {
        return ;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
    {
        [[NSFileManager defaultManager] createFileAtPath:localPath contents:localData attributes:nil];
    }
}
- (void)cacheImageToDisk:(NSDictionary *)info
{
    NSString *URL = [info objectForKey:@"url"];
    UIImage *image = [info objectForKey:@"image"];
    
    NSString *localPath = [diskCachePath stringByAppendingPathComponent:[URL md5]];
    NSData *localData = UIImageJPEGRepresentation(image, 1.0f);
    
    if ([localData length] <= 1)
    {
        return ;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
    {
        [[NSFileManager defaultManager] createFileAtPath:localPath contents:localData attributes:nil];
    }
}

#pragma URLCache 方法

- (void)cacheToDiskWithImageData:(NSData *)imageData withKey:(NSString *)key
{
    UIImage *image = [UIImage imageWithData:imageData];
    [onlyMemoryCache setObject:image forKey:key];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:image,@"image",key,@"url" ,nil];
    NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                             selector:@selector(cacheImageToMemoryDisk:)
                                                                               object:info] autorelease];
    [cacheInQueue addOperation:operation];
}
- (NSData *)getImageDataWithKey:(NSString *)key
{
    UIImage *image;
    NSData *imageData;
    if([onlyMemoryCache objectForKey:key])
    {
        image = [onlyMemoryCache objectForKey:key];
        imageData = UIImageJPEGRepresentation(image, 1.0f);
        NSData *returnData = [[NSData alloc] initWithData:imageData];
        return [returnData autorelease];
    }
    else
    {
        NSString *localPath = [diskMemoryCachePath stringByAppendingPathComponent:[key md5]];;
        image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
        if (image != nil)
        {
            [onlyMemoryCache setObject:image forKey:key];
            imageData = UIImageJPEGRepresentation(image, 1.0f);
            NSData *returnData = [[NSData alloc] initWithData:imageData];
            return [returnData autorelease];
        }
    }
    if([diskMemoryCache objectForKey:key])
    {
        image = [diskMemoryCache objectForKey:key];
        imageData = UIImageJPEGRepresentation(image, 1.0f);
        NSData *returnData = [[NSData alloc] initWithData:imageData];
        return [returnData autorelease];
    }
    else
    {
        NSString *localPath = [diskCachePath stringByAppendingPathComponent:[key md5]];;
        image = [[[UIImage alloc] initWithContentsOfFile:localPath] autorelease];
        if (image != nil)
        {
            [diskMemoryCache setObject:image forKey:key];
            imageData = UIImageJPEGRepresentation(image, 1.0f);
            NSData *returnData = [[NSData alloc] initWithData:imageData];
            return [returnData autorelease];
        }
    }
    return nil;
}

@end
