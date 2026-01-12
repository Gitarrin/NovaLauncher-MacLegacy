//
//  FileDownloader.h
//  NovarinLauncher
//
//  Created by bruhdude on 1/10/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^DownloadProgressBlock)(int64_t received, int64_t expected);
typedef void (^DownloadCompletionBlock)(NSURL *location, NSError *error);

@interface FileDownloader : NSObject <NSURLSessionDownloadDelegate>

@property (atomic, assign) BOOL downloadSucceeded;
- (void)downloadFromURL:(NSURL *)url
               progress:(DownloadProgressBlock)progress
             completion:(DownloadCompletionBlock)completion;

@end

