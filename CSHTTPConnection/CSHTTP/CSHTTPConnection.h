//
//  CSHTTPConnection.h
//  CSHTTPConnection
//
//  Created by TheSooth on 3/13/13.
//  Copyright (c) 2013 TheSooth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "CSHTTPResponse.h"

@class CSHTTPConnection;

@protocol CSHTTPConnectionDelegate <NSObject>

- (void)connection:(CSHTTPConnection *)aConnection didReceiveResponse:(CSHTTPResponse *)aResponse;

- (void)connection:(CSHTTPConnection *)aConnection didReceiveData:(NSData *)aData;

- (void)connection:(CSHTTPConnection *)aConnection didFailWithError:(NSError *)aError;

- (void)connectionDidFinishLoading:(CSHTTPConnection *)connection;

@end

@interface CSHTTPConnection : NSObject

@property (nonatomic, strong) NSDictionary *httpHeaders;
@property (nonatomic, strong) NSData *body;

@property (nonatomic, strong) NSString *URLString;

@property (nonatomic, assign) CGFloat timeOutInterval;

@property (nonatomic, strong) NSString *httpMethod;

@property (nonatomic, assign) NSInteger bufferLength;

@property (nonatomic, strong) id <CSHTTPConnectionDelegate> delegate;

- (void)start;
- (void)stop;
- (void)cancel;

@end
