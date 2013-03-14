//
//  CSHTTPConnection.m
//  CSHTTPConnection
//
//  Created by TheSooth on 3/13/13.
//  Copyright (c) 2013 TheSooth. All rights reserved.
//

#import "CSHTTPConnection.h"

#define kBufferLength 1024
#define kTimeOutInterval 60

enum ErrorActions {
    CancelAction = 100,
    NetworkAction = 101,
    StreamAction = 102,
    TimeOutAction = 103
    };

static const CFOptionFlags kMyNetworkEvents =
  kCFStreamEventOpenCompleted
| kCFStreamEventHasBytesAvailable
| kCFStreamEventEndEncountered
| kCFStreamEventErrorOccurred;

@interface CSHTTPConnection ()

@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, assign) BOOL isFinished;

@property (nonatomic, assign) CFHTTPMessageRef messageRequest;
@property (nonatomic, assign) CFReadStreamRef readStream;

@property (nonatomic, assign) NSTimeInterval lastCheckedTimeInterval;

@property (nonatomic, assign) NSInteger statusCode;

@end

@implementation CSHTTPConnection

- (id)init
{
    self = [super init];
    
    if (self) {
        self.bufferLength = kBufferLength;
        self.timeOutInterval = kTimeOutInterval;
    }
    
    return self;
}

- (void)setupRequest
{
    CFURLRef URL = CFURLCreateWithString(kCFAllocatorDefault, (__bridge CFStringRef)(self.URLString), NULL);
    self.messageRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (__bridge CFStringRef)(self.httpMethod), URL,
                               kCFHTTPVersion1_1);
    
    CFHTTPMessageSetBody(self.messageRequest, (__bridge CFDataRef)(self.body));
    
    [self setupHTTPHeaders];
}

- (void)start
{
    [self setupRequest];
    [self setupReadStream];
    
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, ^{
        [self handleStreamStatus];
    });
}

- (void)setupReadStream
{
    self.readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, self.messageRequest);
    CFReadStreamOpen(self.readStream);
    CFRelease(self.messageRequest);
    
    CFStreamClientContext streamContext = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    CFReadStreamSetClient(self.readStream, kMyNetworkEvents, &streamCallBack, &streamContext);
    
    CFReadStreamScheduleWithRunLoop(self.readStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (void)handleStreamStatus
{
    while(!self.isCancelled && !self.isFinished) {
        SInt32 result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, NO);
        
        if (result == kCFRunLoopRunStopped) {
            self.isCancelled = YES;
            break;
        } if (result == kCFRunLoopRunFinished) {
            self.isFinished = YES;
            break;
        }
        
        if (!CFReadStreamGetStatus(self.readStream)) break;
        
        [self checkTimeOut];
    }
    
    [self stop];
}

- (void)checkTimeOut
{
    NSTimeInterval currentTimeInterval = [NSDate timeIntervalSinceReferenceDate];
    
    if (self.lastCheckedTimeInterval <= 0) {
        self.lastCheckedTimeInterval = currentTimeInterval;
        
        return;
    }
    
    BOOL cancelByTimeOut = (currentTimeInterval - self.lastCheckedTimeInterval) > self.timeOutInterval;
    
    if (cancelByTimeOut) {
        [self generateErrorFromAction:TimeOutAction];
    } else {
        self.lastCheckedTimeInterval = currentTimeInterval;
    }
}

- (void)cancel
{
    self.isCancelled = YES;
    [self generateErrorFromAction:CancelAction];
}

- (void)stop
{
    CFRunLoopStop(CFRunLoopGetCurrent());
    
    CFReadStreamSetClient(self.readStream, 0, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(self.readStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    CFReadStreamClose(self.readStream);
}

static void streamCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *clientCallBackInfo)
{
    CSHTTPConnection *context = (__bridge CSHTTPConnection *)clientCallBackInfo;
    
    if (handleNetworkEvent(type, context)) {
        CSHTTPResponse *response = responseFromReadStream(readStream, context);
        
        [context.delegate connection:context didReceiveResponse:response];
        
        
        NSData *data = parseResponseDataFromStream(readStream, context);
        
        [context.delegate connection:context didReceiveData:data];
    }
}

NSData *parseResponseDataFromStream(CFReadStreamRef readStream, CSHTTPConnection *context)
{
    NSInteger bufferLength = [context bufferLength];
    
    NSMutableData *data = [NSMutableData new];
    unsigned int len = 0;
    
    UInt8 buffer[bufferLength];
    
    len = [(__bridge NSInputStream *)readStream read:buffer maxLength:bufferLength];
    if (len > 0 && len !=NSNotFound) {
        [data appendBytes:&buffer length:len];
    }
    
    return data;
}

#pragma mark - Helpers

- (void)setupHTTPHeaders
{
    for (NSString *key in self.httpHeaders.allKeys) {
        CFHTTPMessageSetHeaderFieldValue(self.messageRequest, (__bridge CFStringRef)(key), (__bridge CFStringRef)(self.httpHeaders[key]));
    }
}

CSHTTPResponse *responseFromReadStream(CFReadStreamRef readStream, CSHTTPConnection *context)
{
    CFHTTPMessageRef responseMessage = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    CSHTTPResponse *response = [[CSHTTPResponse alloc] initWithHTTPMessage:responseMessage];
    
    [context setStatusCode:response.statusCode];
    
    if (response.statusCode >= 400) {
        [context generateErrorFromAction:NetworkAction];
    }
    
    return response;
}

- (void)generateErrorFromAction:(NSInteger)aAction
{
    NSString *errorMessage;
    NSInteger errorCode;
    CFErrorRef errorRef = NULL;
    NSError *error = nil;
    
    if (aAction == CancelAction) {
        errorMessage = @"Connection canceled";
    } else if (aAction == StreamAction) {
        errorRef = CFReadStreamCopyError(self.readStream);
        error = (__bridge NSError *)errorRef;
    } else if (aAction == NetworkAction) {
        errorCode = self.statusCode;
        errorMessage = [NSString stringWithUTF8String:descriptionForResponseCode(errorCode)];
    } else if (aAction == TimeOutAction) {
        errorCode = 408;
        errorMessage = [NSString stringWithFormat:@"Stoped by TimeOut: TimeOutInterval = %.2f", self.timeOutInterval];
    }
    
    if (!error) {
       error = [NSError errorWithDomain:@"CSHTTPConnection" code:self.statusCode
                                     userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
    }
    
    [self failWithError:error];
}

- (void)failWithError:(NSError *)aError
{
    NSAssert(aError, @"error == nil");
    
    self.isCancelled = YES;
    
    [self.delegate connection:self didFailWithError:aError];
}

CF_INLINE const char *descriptionForResponseCode(int code) {
    switch (code) {
        case 100: return "Continue";
        case 101: return "Switching Protocols";
        case 200: return "OK";
        case 201: return "Created";
        case 202: return "Accepted";
        case 203: return "Non-Authoritative Information";
        case 204: return "No Content";
        case 205: return "Reset Content";
        case 206: return "Partial Content";
        case 300: return "Multiple Choices";
        case 301: return "Moved Permanently";
        case 302: return "Found";
        case 303: return "See Other";
        case 304: return "Not Modified";
        case 305: return "Use Proxy";
        case 307: return "Temporary Redirect";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 402: return "Payment Required";
        case 403: return "Forbidden";
        case 404: return "Not Found";
        case 405: return "Method Not Allowed";
        case 406: return "Not Acceptable";
        case 407: return "Proxy Authentication Required";
        case 408: return "Request Time-out";
        case 409: return "Conflict";
        case 410: return "Gone";
        case 411: return "Length Required";
        case 412: return "Precondition Failed";
        case 413: return "Request Entity Too Large";
        case 414: return "Request-URI Too Large";
        case 415: return "Unsupported Media Type";
        case 416: return "Requested range not satisfiable";
        case 417: return "Expectation Failed";
        case 500: return "Internal Server Error";
        case 501: return "Not Implemented";
        case 502: return "Bad Gateway";
        case 503: return "Service Unavailable";
        case 504: return "Gateway Time-out";
        case 505: return "HTTP Version not supported";
        default:
            if (code < 200) {
                return "Continue";
            } else if (code < 300) {
                return "OK";
            } else if (code < 400) {
                return "Multiple Choices";
            } else if (code < 500) {
                return "Bad Request";
            } else {
                return "Internal Server Error";
            }
    }
}

#pragma mark - Debug methods

BOOL handleNetworkEvent(CFStreamEventType aEventType, CSHTTPConnection *context)
{
    switch (aEventType) {
        case kCFStreamEventHasBytesAvailable:
            return YES;
            break;
        case kCFStreamEventErrorOccurred:
            [context generateErrorFromAction:StreamAction];
            break;
            case kCFStreamEventEndEncountered:
            [context.delegate connectionDidFinishLoading:context];
        default:
            break;
    }
    
    return NO;
}

@end
