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
    if (len > 0 && len != NSUIntegerMax) {
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
        errorMessage = [NSHTTPURLResponse localizedStringForStatusCode:errorCode];
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
