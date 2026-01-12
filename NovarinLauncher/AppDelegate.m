//
//  AppDelegate.m
//  NovarinLauncher
//
//  Created by bruhdude on 1/10/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "AppDelegate.h"
#import "FileDownloader.h"
#import "Logger.h"

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [[NSAppleEventManager sharedAppleEventManager]
     setEventHandler:self andSelector:@selector(handleLaunch:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    [self.window center];
    
    self.logger = [[Logger alloc] init];
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.5);
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        if (!self.isLaunching) {
            [self.logger log:@"No URI provided"];
            [self.logger terminate];
            NSURL *url = [NSURL URLWithString:@"https://novarin.co/app/places"];
            [[NSWorkspace sharedWorkspace] openURL:url];
            [NSApp terminate:nil];
        }
    });
}

- (void)updateUI:(NSString *)status showSmallStatus:(BOOL)showSmallStatus smallStatus:(NSString *)smallStatus showButton:(BOOL)showButton buttonTitle:(NSString *)buttonTitle showProgressCircular:(BOOL)showProgressCircular showProgressBar:(BOOL)showProgressBar indeterminateProgressBar:(BOOL)indeterminateProgressBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.status.stringValue = status;
        [self.smallStatus setHidden:!showSmallStatus];
        self.smallStatus.stringValue = smallStatus;
        [self.button setHidden:!showButton];
        self.button.title = buttonTitle;
        [self.progressCircular setHidden:!showProgressCircular];
        [self.progressBar setHidden:!showProgressBar];
        [self.progressBar setIndeterminate:indeterminateProgressBar];
        if (indeterminateProgressBar) {
            [self.progressBar startAnimation:nil];
        }
    });
}

- (void)handleLaunch:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    urlString = [urlString stringByRemovingPercentEncoding];
    
    [self.logger log:[NSString stringWithFormat:@"Opened via: %@", urlString]];
    
    NSString *base64 = [urlString stringByReplacingOccurrencesOfString:@"novarin:" withString:@""];
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    // NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:decodedData options:0 error:&error];
    
    if (!json) {
        [self updateUI:@"Failed to launch Novarin." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
        
        [self.logger log:@"Failed to decode JSON"];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"A critical error occurred.";
        alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: J";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        
        [self.logger terminate];
        return;
    }
    
    self.isLaunching = true;
    [self.progressCircular startAnimation:nil];
    
    NSDictionary *data = (NSDictionary *)json;
    
    self.status.stringValue = [NSString stringWithFormat:@"Launching Novarin %@...", data[@"version"]];
    if ([data[@"version"] integerValue] != 0 || [data[@"version"] isEqualToString:@"0"]) {
        if([data[@"version"] integerValue] < 2018) {
            [self.logger terminate];
            
            [self updateUI:@"Unsupported Version" showSmallStatus:YES smallStatus:@"This version of Novarin is not supported on macOS." showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
        }
    }
    
    if ([data[@"LaunchType"] isEqualToString:@"client"]) {
        [self launchPlayer:data[@"ticket"] scriptURL:data[@"joinscript"] jobID:data[@"jobid"] placeID:data[@"placeid"] gameVersion:data[@"version"]];
    } else if ([data[@"LaunchType"] isEqualToString:@"studio"]) {
        self.status.stringValue = [NSString stringWithFormat:@"Launching Novarin Studio %@...", data[@"version"]];
        [self launchStudio:data[@"ticket"] scriptURL:data[@"joinscript"] placeID:data[@"placeid"] gameVersion:data[@"version"]];
    } else {
        [self.logger terminate];
        
        [self updateUI:@"Invalid Launch Type" showSmallStatus:NO smallStatus:@"Please ask for help in the Novarin Discord server." showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
    }
}

- (IBAction)closeLauncher:(id)sender {
    [NSApp terminate:nil];
}

- (void)launchPlayer:(NSString *)ticket scriptURL:(NSString *)scriptURL jobID:(NSString *)jobID placeID:(NSString *)placeID gameVersion:(NSString *)gameVersion {
    [self.logger log:@"Fetching latest version information before launching NovarinPlayer"];
    [self fetchVersionInfo:gameVersion
                completion:^(NSString *playerUrl,
                             NSString *studioUrl,
                             NSString *version,
                             NSError *error)
     {
         if (error) {
             [self updateUI:@"Failed to launch Novarin Player." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
             
             [self.logger log:[NSString stringWithFormat:@"Failed to fetch version information from the server: %@", error]];
             NSAlert *alert = [[NSAlert alloc] init];
             alert.messageText = @"A critical error occurred.";
             alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: V";
             [alert addButtonWithTitle:@"OK"];
             [alert runModal];
             
             [self.logger terminate];
             return;
         }
         
         if (![self isVersionUpToDate:version gameVersion:gameVersion]) {
             [self.logger log:@"Out of date, starting installation process"];
             [self install:gameVersion];
             return;
         }
         
         [self.logger log:@"Up to date, launching NovarinPlayer"];
         
         NSTask *task = [[NSTask alloc] init];
         
         NSString *executablePath = [NSString stringWithFormat:@"/Applications/Novarin/%@/NovarinPlayer.app/Contents/MacOS/RobloxPlayer", gameVersion];
         [task setLaunchPath:executablePath];
         
         NSArray *arguments = @[@"-authURL", [NSString stringWithFormat:@"\"http://novarin.co/Login/Negotiate.ashx\""], @"-ticket", [NSString stringWithFormat:@"\"%@\"", ticket], @"-scriptURL", [NSString stringWithFormat:@"\"%@\"", scriptURL]];
         [task setArguments:arguments];
         
         @try {
             [task launch];
             [self.logger terminate];
             
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [NSApp terminate:nil];
             });
         } @catch (NSException *exception) {
             [self updateUI:@"Failed to launch Novarin Player." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
             
             [self.logger log:[NSString stringWithFormat:@"Failed to launch NovarinPlayer: %@", exception.reason]];
             NSAlert *alert = [[NSAlert alloc] init];
             alert.messageText = @"A critical error occurred.";
             alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: L";
             [alert addButtonWithTitle:@"OK"];
             [alert runModal];
             
             [self.logger terminate];
             return;
         }
     }];
}

- (void)launchStudio:(NSString *)ticket scriptURL:(NSString *)scriptURL placeID:(NSString *)placeID gameVersion:(NSString *)gameVersion {
    [self.logger log:@"Fetching latest version information before launching NovarinStudio"];
    [self fetchVersionInfo:gameVersion
                completion:^(NSString *playerUrl,
                             NSString *studioUrl,
                             NSString *version,
                             NSError *error)
     {
         if (error) {
             [self updateUI:@"Failed to launch Novarin Studio." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
             
             [self.logger log:[NSString stringWithFormat:@"Failed to fetch version information from the server: %@", error]];
             NSAlert *alert = [[NSAlert alloc] init];
             alert.messageText = @"A critical error occurred.";
             alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: V";
             [alert addButtonWithTitle:@"OK"];
             [alert runModal];
             
             [self.logger terminate];
             return;
         }
         
         if (![self isVersionUpToDate:version gameVersion:gameVersion]) {
             [self.logger log:@"Out of date, starting installation process"];
             [self install:gameVersion];
             return;
         }
         
         [self.logger log:@"Up to date, launching NovarinStudio"];
         
         NSTask *task = [[NSTask alloc] init];
         
         NSString *executablePath = [NSString stringWithFormat:@"/Applications/Novarin/%@/NovarinStudio.app/Contents/MacOS/RobloxStudio", gameVersion];
         [task setLaunchPath:executablePath];
         
         NSArray *arguments = @[@"-task", [NSString stringWithFormat:@"EditPlace"], @"-placeId", [NSString stringWithFormat:@"%@", placeID]];
         [task setArguments:arguments];
         
         @try {
             [task launch];
             [self.logger terminate];
             
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [NSApp terminate:nil];
             });
         } @catch (NSException *exception) {
             [self updateUI:@"Failed to launch Novarin Studio." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
             
             [self.logger log:[NSString stringWithFormat:@"Failed to launch the Studio application: %@", exception.reason]];
             NSAlert *alert = [[NSAlert alloc] init];
             alert.messageText = @"A critical error occurred.";
             alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: L";
             [alert addButtonWithTitle:@"OK"];
             [alert runModal];
             
             [self.logger terminate];
             return;
         }
     }];
}

- (void)fetchVersionInfo:(NSString *)gameVersion completion:(JSONResultBlock)completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://n.termy.lol/client/setup/client/%@/mac", gameVersion]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task =
    [session dataTaskWithURL:url
           completionHandler:^(NSData *data,
                               NSURLResponse *response,
                               NSError *error)
     {
         if (error) {
             completion(nil, nil, nil, error);
             return;
         }
         
         NSError *jsonError = nil;
         NSDictionary *json =
         [NSJSONSerialization JSONObjectWithData:data
                                         options:0
                                           error:&jsonError];
         
         if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
             completion(nil, nil, nil, jsonError);
             [self.logger log:[NSString stringWithFormat:@"Server returned invalid JSON: %@", jsonError]];
             return;
         }
         
         NSString *playerUrl = json[@"playerUrl"];
         NSString *studioUrl = json[@"studioUrl"];
         NSString *version = json[@"version"];
         
         completion(playerUrl, studioUrl, version, nil);
     }];
    
    [task resume];
}

- (void)storeVersion:(NSString *)version gameVersion:(NSString *)gameVersion {
    NSArray *appSupportDirs = [[NSFileManager defaultManager]
                               URLsForDirectory:NSApplicationSupportDirectory
                               inDomains:NSUserDomainMask];
    
    NSURL *appSupportDir = [appSupportDirs firstObject];
    NSURL *appFolder = [appSupportDir URLByAppendingPathComponent:@"Novarin"];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:appFolder
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
    if (error) {
        [self.logger log:[NSString stringWithFormat:@"Failed to create directory: %@", error]];
    }
    
    NSDictionary *dict = @{
                           @"ver": version
                           };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData) {
        [self.logger log:[NSString stringWithFormat:@"Failed to serialize JSON: %@", error]];
    }
    
    NSURL *jsonFileURL = [appFolder URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", gameVersion]];
    
    [jsonData writeToURL:jsonFileURL options:NSDataWritingAtomic error:&error];
    if (error) {
        [self.logger log:[NSString stringWithFormat:@"Failed to write version file: %@", error]];
    } else {
        [self.logger log:[NSString stringWithFormat:@"Saved %@.json to %@", gameVersion, jsonFileURL.path]];
    }
}

- (BOOL)isVersionUpToDate:(NSString *)version gameVersion:(NSString *)gameVersion {
    NSArray *appSupportDirs = [[NSFileManager defaultManager]
                               URLsForDirectory:NSApplicationSupportDirectory
                               inDomains:NSUserDomainMask];
    
    NSURL *appSupportDir = [appSupportDirs firstObject];
    NSURL *appFolder = [appSupportDir URLByAppendingPathComponent:@"Novarin"];
    
    NSURL *jsonFileURL = [appFolder URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", gameVersion]];
    
    NSError *error = nil;
    NSData *jsonData = [NSData dataWithContentsOfURL:jsonFileURL options:0 error:&error];
    
    if (!jsonData) {
        [self.logger log:[NSString stringWithFormat:@"Failed to read %@.json: %@", gameVersion, error]];
        return false;
    }
    
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:NSJSONReadingMutableContainers
                                                               error:&error];
    if (!jsonDict) {
        [self.logger log:[NSString stringWithFormat:@"Failed to parse %@.json: %@", gameVersion, error]];
        return false;
    }
    
    return [jsonDict[@"ver"] isEqualToString:version];
}

- (void)install:(NSString *)gameVersion {
    NSString *clientDestZip = [NSString stringWithFormat:@"/tmp/NovarinPlayer%@.zip", gameVersion];
    NSString *studioDestZip = [NSString stringWithFormat:@"/tmp/NovarinStudio%@.zip", gameVersion];
    NSString *extractDir = [NSString stringWithFormat:@"/Applications/Novarin/%@/", gameVersion];
    FileDownloader *downloader = [[FileDownloader alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI:@"Fetching information..." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:YES];
    });
    
    [self fetchVersionInfo:gameVersion
                completion:^(NSString *playerUrl,
                             NSString *studioUrl,
                             NSString *version,
                             NSError *error)
     {
         if (error) {
             [self updateUI:@"Failed to fetch information." showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
             
             [self.logger log:[NSString stringWithFormat:@"Failed to fetch version information from the server: %@", error]];
             NSAlert *alert = [[NSAlert alloc] init];
             alert.messageText = @"A critical error occurred.";
             alert.informativeText = @"Please ask for help in the Novarin Discord server.\nCode: V";
             [alert addButtonWithTitle:@"OK"];
             [alert runModal];
             return;
         }
         [downloader downloadFromURL:[NSURL URLWithString:playerUrl]
                            progress:^(int64_t received, int64_t expected) {
                                if (expected > 0) {
                                    double progress = (double)received / (double)expected;
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        double percent = progress * 100.0;
                                        [self updateUI:[NSString stringWithFormat:@"Downloading Novarin %@... (1/2)", gameVersion] showSmallStatus:YES smallStatus:[NSString stringWithFormat:@"%.0f%% downloaded", percent] showButton:YES buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:NO];
                                        
                                        self.progressBar.doubleValue = progress;
                                    });
                                }
                            }
                          completion:^(NSURL *location, NSError *error) {
                              if (error) {
                                  [self updateUI:[NSString stringWithFormat:@"Failed to download Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                  
                                  [self.logger log:[NSString stringWithFormat:@"Download failed:%@", error]];
                                  NSAlert *alert = [[NSAlert alloc] init];
                                  alert.messageText = @"An error occurred during installation.";
                                  alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: D";
                                  [alert addButtonWithTitle:@"OK"];
                                  [alert runModal];
                              } else {
                                  [self updateUI:[NSString stringWithFormat:@"Installing Novarin %@... (1/2)", gameVersion] showSmallStatus:YES smallStatus:@"Moving files..." showButton:NO buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:YES];
                                  
                                  NSURL *destinationURL = [NSURL fileURLWithPath:clientDestZip];
                                  NSFileManager *fm = [NSFileManager defaultManager];
                                  
                                  if ([fm fileExistsAtPath:destinationURL.path]) {
                                      NSError *removeError = nil;
                                      [fm removeItemAtURL:destinationURL error:&removeError];
                                      if (removeError) {
                                          [self updateUI:[NSString stringWithFormat:@"Failed to install Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                          
                                          [self.logger log:[NSString stringWithFormat:@"Failed to remove downloaded file: %@", removeError]];
                                          NSAlert *alert = [[NSAlert alloc] init];
                                          alert.messageText = @"An error occurred during installation.";
                                          alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: RM";
                                          [alert addButtonWithTitle:@"OK"];
                                          [alert runModal];
                                          return;
                                      }
                                  }
                                  NSError *moveError = nil;
                                  [fm moveItemAtURL:location toURL:destinationURL  error:&moveError];
                                  if (moveError) {
                                      [self updateUI:[NSString stringWithFormat:@"Failed to install Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                      
                                      [self.logger log:[NSString stringWithFormat:@"Failed to move downloaded file: %@", moveError]];
                                      NSAlert *alert = [[NSAlert alloc] init];
                                      alert.messageText = @"An error occurred during installation.";
                                      alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: M";
                                      [alert addButtonWithTitle:@"OK"];
                                      [alert runModal];
                                      return;
                                  }
                                  
                                  
                                  [self updateUI:[NSString stringWithFormat:@"Installing Novarin %@... (1/2)", gameVersion] showSmallStatus:YES smallStatus:@"Extracting files, this may take a few minutes..." showButton:NO buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:YES];
                                  
                                  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                      [self unzipFile:clientDestZip toPath:extractDir];
                                      [downloader downloadFromURL:[NSURL URLWithString:studioUrl]
                                                         progress:^(int64_t received, int64_t expected) {
                                                             if (expected > 0) {
                                                                 double progress = (double)received / (double)expected;
                                                                 
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     double percent = progress * 100.0;
                                                                     [self updateUI:[NSString stringWithFormat:@"Downloading Novarin %@... (2/2)", gameVersion] showSmallStatus:YES smallStatus:[NSString stringWithFormat:@"%.0f%% downloaded", percent] showButton:YES buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:NO];
                                                                     
                                                                     self.progressBar.doubleValue = progress;
                                                                 });
                                                             }
                                                         }
                                                       completion:^(NSURL *location, NSError *error) {
                                                           if (error) {
                                                               [self updateUI:[NSString stringWithFormat:@"Failed to download Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                                               
                                                               [self.logger log:[NSString stringWithFormat:@"Failed to download file: %@", error]];
                                                               NSAlert *alert = [[NSAlert alloc] init];
                                                               alert.messageText = @"An error occurred during installation.";
                                                               alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: D";
                                                               [alert addButtonWithTitle:@"OK"];
                                                               [alert runModal];
                                                           } else {
                                                               [self updateUI:[NSString stringWithFormat:@"Installing Novarin %@... (2/2)", gameVersion] showSmallStatus:YES smallStatus:@"Moving files..." showButton:NO buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:YES];
                                                               
                                                               NSURL *destinationURL = [NSURL fileURLWithPath:studioDestZip];
                                                               NSFileManager *fm = [NSFileManager defaultManager];
                                                               
                                                               if ([fm fileExistsAtPath:destinationURL.path]) {
                                                                   NSError *removeError = nil;
                                                                   [fm removeItemAtURL:destinationURL error:&removeError];
                                                                   if (removeError) {
                                                                       [self updateUI:[NSString stringWithFormat:@"Failed to install Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                                                       
                                                                       [self.logger log:[NSString stringWithFormat:@"Failed to remove downloaded file: %@", removeError]];
                                                                       NSAlert *alert = [[NSAlert alloc] init];
                                                                       alert.messageText = @"An error occurred during installation.";
                                                                       alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: RM";
                                                                       [alert addButtonWithTitle:@"OK"];
                                                                       [alert runModal];
                                                                       return;
                                                                   }
                                                               }
                                                               NSError *moveError = nil;
                                                               [fm moveItemAtURL:location toURL:destinationURL  error:&moveError];
                                                               if (moveError) {
                                                                   [self updateUI:[NSString stringWithFormat:@"Failed to install Novarin %@.", gameVersion] showSmallStatus:NO smallStatus:@"" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                                                   
                                                                   [self.logger log:[NSString stringWithFormat:@"Failed to move downloaded file: %@", moveError]];
                                                                   NSAlert *alert = [[NSAlert alloc] init];
                                                                   alert.messageText = @"An error occurred during installation.";
                                                                   alert.informativeText = @"Please ask for help in the Novarin Discord server.\nError code: M";
                                                                   [alert addButtonWithTitle:@"OK"];
                                                                   [alert runModal];
                                                                   return;
                                                               }
                                                               
                                                               [self updateUI:[NSString stringWithFormat:@"Installing Novarin %@... (2/2)", gameVersion] showSmallStatus:YES smallStatus:@"Extracting files, this may take a few minutes..." showButton:NO buttonTitle:@"Cancel" showProgressCircular:NO showProgressBar:YES indeterminateProgressBar:YES];
                                                               
                                                               dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                                   [self unzipFile:studioDestZip toPath:extractDir];
                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                       self.progressBar.doubleValue = 1.0;
                                                                       
                                                                       [self updateUI:[NSString stringWithFormat:@"Novarin %@ IS SUCCESSFULLY INSTALLED!", gameVersion] showSmallStatus:YES smallStatus:@"Click the 'Play' button on any game to join the action!" showButton:YES buttonTitle:@"OK" showProgressCircular:NO showProgressBar:NO indeterminateProgressBar:NO];
                                                                       
                                                                       [self storeVersion:version gameVersion:gameVersion];
                                                                       
                                                                       [self.logger terminate];
                                                                   });
                                                               });
                                                           }
                                                       }];
                                  });
                              }
                          }];
     }];
}

- (void)unzipFile:(NSString *)zipPath toPath:(NSString *)destination {
    [[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/unzip"];
    [task setArguments:@[ @"-qo", zipPath, @"-d", destination ]];
    
    [task launch];
    [task waitUntilExit];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.logger terminate];
}

@end
