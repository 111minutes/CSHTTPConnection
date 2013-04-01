//
//  CSHTTPResponse.m
//  CSHTTPConnection
//
//  Created by TheSooth on 3/13/13.
//  Copyright (c) 2013 TheSooth. All rights reserved.
//

#import "CSHTTPResponse.h"

@implementation CSHTTPResponse

- (id)initWithHTTPMessage:(CFHTTPMessageRef)aMessage
{
    self = [super init];
    
    if (self) {
        [self generateResponseFromMessage:aMessage];
    }
    
    return self;
}

- (void)generateResponseFromMessage:(CFHTTPMessageRef)aMessage
{
    
    self.statusCode = CFHTTPMessageGetResponseStatusCode(aMessage);
    self.allHeadersFileds = (__bridge_transfer NSDictionary *)(CFHTTPMessageCopyAllHeaderFields(aMessage));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"statusCode = %d\nHeaders = %@", self.statusCode, self.allHeadersFileds];
}

@end
