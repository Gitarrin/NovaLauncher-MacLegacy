//
//  Logger.h
//  NovarinLauncher
//
//  Created by bruhdude on 1/11/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NSFileHandle;

@interface Logger : NSObject

@property (nonatomic, strong) NSFileHandle *fileHandle;

- (void)log:(NSString *)message;
- (void)terminate;

@end
