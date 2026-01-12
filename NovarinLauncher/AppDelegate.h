//
//  AppDelegate.h
//  NovarinLauncher
//
//  Created by bruhdude on 1/10/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Logger.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *status;
@property (weak) IBOutlet NSTextField *smallStatus;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSProgressIndicator *progressCircular;
@property (weak) IBOutlet NSButton *button;
@property (nonatomic, assign) BOOL isLaunching;

- (void)launchPlayer:(NSString *)ticket scriptURL:(NSString *)scriptURL jobID:(NSString *)jobID placeID:(NSString *)placeID gameVersion:(NSString *)gameVersion;
- (void)launchStudio:(NSString *)ticket scriptURL:(NSString *)scriptURL placeID:(NSString *)placeID gameVersion:(NSString *)gameVersion;
- (IBAction)closeLauncher:(id)sender;

typedef void (^JSONResultBlock)(NSString *playerUrl,
                                NSString *studioUrl,
                                NSString *version,
                                NSError *error);

@property NSURLDownload *download;
@property long long expectedBytes;
@property long long receivedBytes;
@property NSString *downloadedZipPath;
@property Logger *logger;

@end
