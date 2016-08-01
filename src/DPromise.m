//
//  MSPromise.m
//  MySearch
//
//  Created by Alexander Sviridov on 30/11/15.
//  Copyright © 2015 Alexander Sviridov. All rights reserved.
//

#import "DPromise.h"

//#import "LinqToObjectiveC.h"
#import "DCollections.h"

@interface DPromiseListengerContainer : NSObject

@property DPromise *promise;
@property (copy) void(^onCompleate)(id, NSError *, DPromise *);

@end

@implementation DPromiseListengerContainer

+ (instancetype)listengerWithPromise:(DPromise *)promise compleationBlock:(void(^)(id, NSError *, DPromise *))compleation
{
    DPromiseListengerContainer *container = [DPromiseListengerContainer new];
    container.promise = promise;
    container.onCompleate = compleation;
    return container;
}

@end

@interface DPromise ()

@property NSArray<DPromiseListengerContainer *> *listengers;
@property id compleatedValue;
@property NSError *compleatedError;
@property (weak) DPromise *prevPromise;
@property (copy) DPromiseDisposable disposableBlock;

@end

@implementation DPromise

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        _listengers = [NSMutableArray new];
    }
    return self;
}

+ (instancetype)newPromise:(DPromiseDisposable (^)(DPromiseFullfillBlock, DPromiseRejectBclock))block
{
    DPromise *resultPromise = [DPromise new];
    resultPromise.debugName = [self callStackName:0];
    resultPromise.disposableBlock = block(^(id fullfil){
        [resultPromise onValue:fullfil error:nil];
    }, ^(NSError *reject){
        [resultPromise onValue:nil error:reject];
    });
    
    return resultPromise;
}

+ (NSString *)callStackName:(NSInteger)stackIndex
{
    return [self string:[NSThread callStackSymbols][stackIndex + 2] ByRemovingRegex:@".+0x[0-9a-f]+\\s"];
}

+ (instancetype)promiseWithValue:(id)value
{
    DPromise *promise = [self newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil, DPromiseRejectBclock reject) {
        fullfil( value );
        return ^{
        };
    }];
    promise.debugName = [NSString stringWithFormat:@"%@ Value[%@]:%@", [self callStackName:0], NSStringFromClass([value class]), value];
    return promise;
}

+ (instancetype)promiseWithError:(NSError *)error
{
    DPromise *promise = [self newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil, DPromiseRejectBclock reject) {
        reject(error);
        return ^{
        };
    }];
    promise.debugName = [NSString stringWithFormat:@"%@ Error[%@]:%@", [self callStackName:0], NSStringFromClass([error class]), error];
    return promise;
}

- (id)then:(DPromise *(^)(id))thenBlock
{
    return [self then:thenBlock onQueue:dispatch_get_main_queue()];
}

- (id)thenOnBackground:(DPromise *(^)(id))thenBlock
{
    return [self then:thenBlock onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (id)then:(DPromise *(^)(id))thenBlock onQueue:(dispatch_queue_t)queue
{
    DPromise *newPromise = [DPromise new];
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"then%@ ", [DPromise callStackName:1] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id next, NSError *error, DPromise *owner) {
        if ( !error ) {
            dispatch_async(queue, ^{
                DPromise *nextPromise = thenBlock(next);
                if ( !nextPromise )
                    [owner onValue:next error:nil];
                else if ( [nextPromise isKindOfClass:[DPromise class]] ) {
                    owner.debugName = [owner.debugName stringByAppendingFormat:@"(promise:%@)", nextPromise.debugName ];
                    [nextPromise addListengerWithPromise:owner onCompleation:^(id next, NSError *error, DPromise *owner) {
                        [owner onValue:next error:error];
                    }];
                }
                else if ( [nextPromise isKindOfClass:[NSError class]] )
                    [owner onValue:nil error:(NSError *)nextPromise];
                else
                    [owner onValue:nextPromise error:nil];
            });
            return;
        }
        else
            [owner onValue:nil error:error];
    }];
    return newPromise;
}

- (id)catch:(DPromise *(^)(NSError *))rejectErrorBlock
{
    DPromise *newPromise = [DPromise new];
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"catch%@ ", [DPromise callStackName:1] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id next, NSError *error, DPromise *owner) {
        if ( error ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DPromise *nextPromise = rejectErrorBlock(error);
                if ( !nextPromise )
                    [owner onValue:nil error:error];
                else if ( [nextPromise isKindOfClass:[DPromise class]] ) {
                    owner.debugName = [owner.debugName stringByAppendingFormat:@"(promise%@)", nextPromise.debugName ];
                    [nextPromise addListengerWithPromise:owner onCompleation:^(id next, NSError *error, DPromise *owner) {
                        [owner onValue:next error:error];
                    }];
                }
                else if ( [nextPromise isKindOfClass:[NSError class]] )
                    [owner onValue:nil error:(NSError *)nextPromise];
                else
                    [owner onValue:nextPromise error:nil];
            });
        }
        else
            [owner onValue:next error:nil];
    }];
    return newPromise;
}

- (id)once
{
    if ( self.isCompleated )
        return self.compleatedError ? [DPromise promiseWithError:self.compleatedError] : [DPromise promiseWithValue:self.compleatedValue];
    
    return [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fulfil, DPromiseRejectBclock reject) {
        __weak DPromise *promise = [[self then:^DPromise *(id result) {
            fulfil( result );
            return nil;
        }] catch:^DPromise *(NSError *error) {
            reject( error );
            return nil;
        }];
        return ^{
            if ( promise ) [promise dispose];
        };
    }];
}

- (void)dispose
{
    @synchronized(self) {
        if ( self.prevPromise )
            [self.prevPromise removeListenerWithPromise:self];
        if ( self.disposableBlock )
            self.disposableBlock();
    };
}

#pragma mark - private

- (void)cleanInvalidListengers
{
    self.listengers = [self.listengers mapArray:^id(DPromiseListengerContainer *container) {
        if ( !container.promise ) {
            container.onCompleate = nil;
            return nil;
        }
        return container;
    }];
}

- (void)addListengerWithPromise:(DPromise *)promise onCompleation:(void(^)(id, NSError *, DPromise *))compleationBlock
{
    @synchronized( self ) {
        if ( promise.prevPromise ) {
            [promise.prevPromise removeListenerWithPromise:self];
        }
        promise.prevPromise = self;
        if ( self.isCompleated ) {
            compleationBlock(self.compleatedValue, self.compleatedError, promise);
        }
        self.listengers = [self.listengers arrayByAddingObject:[DPromiseListengerContainer listengerWithPromise:promise compleationBlock:compleationBlock]];
    }
}

- (void)removeListenerWithPromise:(DPromise *)promise
{
    @synchronized( self ) {
        [self cleanInvalidListengers];
        self.listengers = [self.listengers mapArray:^id(DPromiseListengerContainer *object) {
            return object.promise == promise ? nil : object;
        }];
        if ( !self.listengers.count )
            [self dispose];
    }
}

- (void)onValue:(id)prevValue error:(NSError *)error
{
    _isCompleated = YES;
    self.compleatedError = error;
    self.compleatedValue = prevValue;
    [self cleanInvalidListengers];
    self.debugName = [self.debugName stringByAppendingFormat:@"(%s:[%@])", error? "error": prevValue ? "value" : "nil", NSStringFromClass(error?[error class]: [prevValue class]) ];
    [self.listengers enumerateObjectsUsingBlock:^(DPromiseListengerContainer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( error )
            obj.onCompleate(nil, error, obj.promise );
        if ( prevValue )
            obj.onCompleate(prevValue,nil, obj.promise );
    }];
}

- (void)dealloc
{
    if ( self.prevPromise )
        [self.prevPromise removeListenerWithPromise:self];
}

+ (NSString *)string:(NSString *)string ByRemovingRegex:(NSString *)regex
{
    __autoreleasing NSError *error = nil;
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:&error];
    NSRange rangeOfFirstMatch = [regularExpression rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    NSString *regexOccurentString = [string substringWithRange:rangeOfFirstMatch];
    return [string stringByReplacingOccurrencesOfString:regexOccurentString withString:@""];
}

@end

