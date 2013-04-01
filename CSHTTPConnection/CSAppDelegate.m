//
//  CSAppDelegate.m
//  CSHTTPConnection
//
//  Created by TheSooth on 3/13/13.
//  Copyright (c) 2013 TheSooth. All rights reserved.
//

#import "CSAppDelegate.h"
#import "CSHTTPConnection.h"

@interface CSAppDelegate () <CSHTTPConnectionDelegate>

@property (nonatomic, strong) CSHTTPConnection *connection;

@end

@implementation CSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    self.connection = [CSHTTPConnection new];
    
    self.connection.httpHeaders = @{@"SomeHeader" : @"HeaderValue"};
    self.connection.URLString = @"http://111minutes.com";
    self.connection.httpMethod = @"GET";
    self.connection.delegate = self;
    self.connection.bufferLength = 2048;
    
    [self.connection start];
    
    return YES;
}

- (void)connection:(CSHTTPConnection *)aConnection didReceiveData:(NSData *)aData
{
    NSLog(@"DataLenght = %u", aData.length);
    
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dataFile"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:aData];
    [fileHandle closeFile];
}

- (void)connectionDidFinishLoading:(CSHTTPConnection *)connection
{
    
}

- (void)connection:(CSHTTPConnection *)aConnection didReceiveResponse:(CSHTTPResponse *)aResponse
{
    NSLog(@"Response = %@", aResponse);
}

- (void)connection:(CSHTTPConnection *)aConnection didFailWithError:(NSError *)aError
{
    NSLog(@"Error = %@", aError);
}

@end
