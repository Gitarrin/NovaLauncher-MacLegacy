//
//  Logger.m
//  NovarinLauncher
//
//  Created by bruhdude on 1/11/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "Logger.h"
#import <Foundation/NSFileHandle.h>

@implementation Logger

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupLogFile];
    }
    return self;
}

- (void)setupLogFile {
    NSArray *appSupportDirs = [[NSFileManager defaultManager]
                               URLsForDirectory:NSApplicationSupportDirectory
                               inDomains:NSUserDomainMask];
    
    NSURL *appSupportDir = [appSupportDirs firstObject];
    NSURL *appFolder = [appSupportDir URLByAppendingPathComponent:@"Novarin/logs"];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:appFolder
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM-dd-yy_HH-mm-ss"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSURL *logFileURL = [appFolder URLByAppendingPathComponent:[NSString stringWithFormat:@"log_%@.json", dateString]];
    
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:logFileURL.path];

    if (!exists) {
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:logFileURL.path contents:nil attributes:nil];
        if (success) {
            NSLog(@"Log file created at %@", logFileURL.path);
        } else {
            NSLog(@"Failed to create log file: %@", error);
        }
    }
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFileURL.path];
    [self.fileHandle seekToEndOfFile];
}

- (void)log:(NSString *)message {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSString *applicationString = @"NovarinLauncher";
    
    NSString *fullMessage = [NSString stringWithFormat:@"[%@]-[%@] %@\n", applicationString, dateString, message];
    
    NSLog(fullMessage);
    
    [self.fileHandle writeData:[fullMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [self.fileHandle synchronizeFile];

}

- (void)terminate {
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM-dd-yy_HH-mm-ss"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSLog(@"Log file saved to %@.json", dateString);
    [self.fileHandle closeFile];
}
@end
