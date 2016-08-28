//
//  MSPromise.m
//  MySearch
//
//  Created by Alexander Sviridov on 30/11/15.
//  Copyright © 2015 Alexander Sviridov. All rights reserved.
//

#import "DPromise.h"

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

- (id)then:(id(^)(id))thenBlock
{
    return [self then:thenBlock onQueue:dispatch_get_main_queue()];
}

- (id)thenOnBackground:(id(^)(id))thenBlock
{
    return [self then:thenBlock onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (id)then:(id(^)(id))thenBlock onQueue:(dispatch_queue_t)queue
{
    DPromise *newPromise = [DPromise new];
    if ( !thenBlock ) {
        return self;
    }
    dispatch_queue_t runningQueue = queue ?: dispatch_get_main_queue();
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"then%@ ", [DPromise callStackName:1] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id next, NSError *error, DPromise *owner) {
        if ( !error ) {
            dispatch_async(runningQueue, ^{
                DPromise *nextPromise = thenBlock(next);
                if ( [nextPromise isKindOfClass:[DPromise class]] ) {
                    nextPromise->_queue = runningQueue;
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

- (id)thenOnCurrentThread:(id (^)(id))thenBlock
{
    return [self then:thenBlock onQueue:_queue];
}

- (id)catch:(id(^)(NSError *))rejectErrorBlock
{
    return [self catch:rejectErrorBlock onQueue:dispatch_get_main_queue()];
}

- (id)catchOnBackground:(id (^)(NSError *))rejectErrorBlock
{
    return [self catch:rejectErrorBlock onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (id)catchOnCurrentThread:(id (^)(NSError *))rejectErrorBlock
{
    return [self catch:rejectErrorBlock onQueue:_queue];
}

- (id)catch:(id (^)(NSError *))rejectErrorBlock onQueue:(dispatch_queue_t)queue
{
    DPromise *newPromise = [DPromise new];
    dispatch_queue_t runningQueue = queue ?: dispatch_get_main_queue();
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"catch%@ ", [DPromise callStackName:1] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id next, NSError *error, DPromise *owner) {
        if ( error ) {
            dispatch_async(runningQueue, ^{
                DPromise *nextPromise = rejectErrorBlock(error);
                nextPromise->_queue = runningQueue;
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

+ (DPromise *)merge:(DPromise *)promise withPromise:(DPromise *)otherPromise
{
    return [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil, DPromiseRejectBclock reject) {
        __block id firstValue = nil, secondValue = nil;
        DPromise *firstPromise, *secondPromise;
        void (^invoke)() = ^{
            if ( firstValue && secondValue ) {
                fullfil( [@[ firstValue, secondValue] flattern] );
            }
        };
        
        if ( [promise isKindOfClass:[DPromise class]] ) {
            firstPromise = [promise then:^id(id nextFirstValue) {
                firstValue = nextFirstValue;
                invoke();
                return nextFirstValue;
            }];
        }
        else {
            firstValue = promise;
        }
        
        if ( [otherPromise isKindOfClass:[DPromise class]] ) {
            secondPromise = [otherPromise then:^id(id nextSecondValue) {
                secondValue = nextSecondValue;
                invoke();
                return nextSecondValue;
            }];
        }
        else {
            secondValue = otherPromise;
        }
        
        invoke();
        
        return ^{
            [firstPromise dispose];
            [secondPromise dispose];
        };
    }];
}

+ (DPromise<NSArray *> *)merge:(NSArray<DPromise *> *)mergingArray
{
    if ( !mergingArray.count )
        return nil;
    if ( mergingArray.count == 1 ) {
        DPromise *mergePromise = mergingArray[0];
        if ( [mergePromise isKindOfClass:[DPromise class]] ) {
            return [mergePromise then:^id(id value) {
                return @[ value ];
            }];
        }
        return [DPromise promiseWithValue:mergePromise];
    }
    if ( mergingArray.count == 2 ) {
        return [DPromise merge:mergingArray[0] withPromise:mergingArray[1]];
    }
    return [DPromise merge:mergingArray[0] withPromise:[self merge:({
        NSMutableArray *otherArray = [mergingArray mutableCopy];
        [otherArray removeObjectAtIndex:0];
        [otherArray copy];
    })]];
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

