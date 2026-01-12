//
//  FileDownloader.m
//  NovarinLauncher
//
//  Created by bruhdude on 1/10/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "FileDownloader.h"

@interface FileDownloader ()
@property (nonatomic, copy) DownloadProgressBlock progressBlock;
@property (nonatomic, copy) DownloadCompletionBlock completionBlock;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation FileDownloader

- (void)downloadFromURL:(NSURL *)url
               progress:(DownloadProgressBlock)progress
             completion:(DownloadCompletionBlock)completion
{
    self.progressBlock = progress;
    self.completionBlock = completion;
    
    NSURLSessionConfiguration *config =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    self.session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:queue];

    
    NSURLSessionDownloadTask *task =
    [self.session downloadTaskWithURL:url];
    
    [task resume];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (self.progressBlock) {
        self.progressBlock(totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    self.downloadSucceeded = YES;
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Novarin"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    NSUInteger length = 10;
    NSMutableString *filename = [NSMutableString stringWithCapacity:length];
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    for (NSUInteger i = 0; i < length; i++) {
        uint32_t idx = arc4random_uniform((uint32_t)letters.length);
        unichar c = [letters characterAtIndex:idx];
        [filename appendFormat:@"%C", c];
    }
    
    NSURL *safeLocation = [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", filename]]];
    
    NSError *copyError = nil;
    [[NSFileManager defaultManager] copyItemAtURL:location toURL:safeLocation error:&copyError];
    if (copyError) {
        NSLog(@"Failed to copy temporary file: %@", copyError);
    }
    
    if (self.completionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(safeLocation, nil);
        });
    }
    
    [self.session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    if (error) {
        if(error.code == NSURLErrorCancelled && self.downloadSucceeded) {
            return;
        }
        
        if(self.completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(nil, error);
            });
        }
    }
}


@end

