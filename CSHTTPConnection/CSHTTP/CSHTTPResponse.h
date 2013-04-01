//
//  CSHTTPResponse.h
//  CSHTTPConnection
//
//  Created by TheSooth on 3/13/13.
//  Copyright (c) 2013 TheSooth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSHTTPResponse : NSObject

@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, strong) NSDictionary *allHeadersFileds;

- (id)initWithHTTPMessage:(CFHTTPMessageRef)aMessage;

@end
