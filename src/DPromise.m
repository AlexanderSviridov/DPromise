//
//  MSPromise.m
//  MySearch
//
//  Created by Alexander Sviridov on 30/11/15.
//  Copyright © 2015 Alexander Sviridov. All rights reserved.
//

#import "DPromise.h"

#import "DCollections.h"

@interface DWeakContainer<ObjType> : NSObject

@property (weak) ObjType value;

@end

@implementation DWeakContainer

@end

@interface DPromiseListengerContainer : NSObject

@property DPromise *promise;
@property (copy) void(^onCompleate)(id, DPromise *);

@end

@implementation DPromiseListengerContainer

+ (instancetype)listengerWithPromise:(DPromise *)promise compleationBlock:(void(^)(id, DPromise *))compleation
{
    DPromiseListengerContainer *container = [DPromiseListengerContainer new];
    container.promise = promise;
    container.onCompleate = compleation;
    return container;
}

@end

static BOOL __dPromiseDebbugLogging = NO;

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
    if ( self ) {
        _listengers = [NSMutableArray new];
        self.repeatingLast = YES;
        if ( __dPromiseDebbugLogging )
            [DPromise addListedSignal:self];
    }
    return self;
}

+ (instancetype)newPromise:(DPromiseDisposable (^)(DPromiseFullfillBlock))block
{
    DPromise *resultPromise = [DPromise new];
    resultPromise.debugName = [self callStackName:0];
    resultPromise.disposableBlock = block(^(id fullfil){
        [resultPromise sendNext:fullfil];
    });
    
    return resultPromise;
}

+ (NSString *)callStackName:(NSInteger)stackIndex
{
    return [self string:[NSThread callStackSymbols][stackIndex + 2] ByRemovingRegex:@".+0x[0-9a-f]+\\s"];
}

+ (instancetype)promiseWithValue:(id)value
{
    DPromise *promise = [self newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        fullfil( value );
        return ^{
        };
    }];
    promise.debugName = [NSString stringWithFormat:@"%@ Value[%@]:%@", [self callStackName:0], NSStringFromClass([value class]), value];
    return promise;
}

+ (instancetype)promiseWithError:(NSError *)error
{
    DPromise *promise = [self newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        fullfil(error);
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
//    dispatch_queue_t runningQueue = queue ?: dispatch_get_main_queue();
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"then%@ ", [DPromise callStackName:1] ];
    typeof(self) self_weak__ = self;
    [self addListengerWithPromise:newPromise onCompleation:^(id next, DPromise *owner) {
        if ( ![next isKindOfClass:[NSError class]] ) {
            void (^block)() = ^{
                @synchronized (self_weak__) {
                    DPromise *nextPromise = thenBlock(next);
                    if ( [nextPromise isKindOfClass:[DPromise class]] ) {
                        nextPromise->_queue = queue;
                        owner.debugName = [owner.debugName stringByAppendingFormat:@"(promise:%@)", nextPromise.debugName ];
                        [nextPromise addListengerWithPromise:owner onCompleation:^(id next, DPromise *owner) {
                            [owner sendNext:next];
                        }];
                    }
                    else
                        [owner sendNext:nextPromise];
                }
            };
            if ( queue ) {
                dispatch_async(queue, block);
            }
            else {
                block();
            }
            return;
        }
        else
            [owner sendNext:next];
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
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"catch%@ ", [DPromise callStackName:1] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id next, DPromise *owner) {
        if ( [next isKindOfClass:[NSError class]] ) {
            void (^block)() = ^{
                DPromise *nextPromise = rejectErrorBlock(next);
                if ( !nextPromise )
                    [owner sendNext:next];
                else if ( [nextPromise isKindOfClass:[DPromise class]] ) {
                    nextPromise->_queue = queue;
                    owner.debugName = [owner.debugName stringByAppendingFormat:@"(promise%@)", nextPromise.debugName ];
                    [nextPromise addListengerWithPromise:owner onCompleation:^(id next, DPromise *owner) {
                        [owner sendNext:next];
                    }];
                }
                else
                    [owner sendNext:nextPromise];
            };
            if ( queue ) {
                dispatch_async(queue, block);
            }
            else {
                block();
            }
        }
        else
            [owner sendNext:next];
    }];
    return newPromise;
    
}

- (id)once
{
    if ( self.isCompleated )
        return self.compleatedError ? [DPromise promiseWithError:self.compleatedError] : [DPromise promiseWithValue:self.compleatedValue];
    
    return [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fulfil) {
        __weak DPromise *promise = [[self then:^DPromise *(id result) {
            fulfil( result );
            return nil;
        }] catch:^DPromise *(NSError *error) {
            fulfil( error );
            return nil;
        }];
        return ^{
            if ( promise ) [promise dispose];
        };
    }];
}

- (instancetype)finaly:(void (^)())block
{
    DPromise *newPromise = [DPromise new];
    if ( !block ) {
        return self;
    }
    newPromise.debugName = [self.debugName stringByAppendingFormat:@"finaly%@ ", [DPromise callStackName:0] ];
    [self addListengerWithPromise:newPromise onCompleation:^(id result, DPromise *promise) {
        block();
    }];
    return newPromise;
}

+ (DPromise *)merge:(DPromise *)promise withPromise:(DPromise *)otherPromise
{
    return [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
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
        return [DPromise promiseWithValue:@[]];
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

- (void)addListengerWithPromise:(DPromise *)promise onCompleation:(void(^)(id, DPromise *))compleationBlock
{
    @synchronized( self ) {
//        if ( promise.prevPromise ) {
//            [promise.prevPromise removeListenerWithPromise:promise];
//        }
        promise.prevPromise = self;
        if ( self.isCompleated && self.repeatingLast ) {
            compleationBlock(self.compleatedValue, promise);
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

- (void)sendNext:(id)nextValue
{
    _isCompleated = YES;
    self.compleatedValue = nextValue;
    [self cleanInvalidListengers];
    self.debugName = [self.debugName stringByAppendingFormat:@"(%s:[%@])", [nextValue isKindOfClass:[NSError class]]? "error": nextValue ? "value" : "nil", NSStringFromClass([nextValue class]) ];
    [self.listengers enumerateObjectsUsingBlock:^(DPromiseListengerContainer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( nextValue )
            obj.onCompleate(nextValue, obj.promise);
    }];
}

- (void)dealloc
{
    if ( __dPromiseDebbugLogging ) {
        NSLog(@"Promises: %@", [self.class.allSignals mapArray:^id(DPromise *promise) {
            return [promise debugName];
        }] );
    }
    [self dispose];
}

#pragma mark - Debbug

+ (NSMutableArray<DWeakContainer<DPromise *> *> *)allSignalsArray
{
    static NSMutableArray<DWeakContainer<DPromise *> *> *__allSignals = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __allSignals = [NSMutableArray new];
    });
    @synchronized (self) {
        __allSignals = [[__allSignals mapArray:^id(DWeakContainer<DPromise *> *container) {
            if ( !container.value ) {
                return nil;
            }
            return container;
        }] mutableCopy];
    }
    return __allSignals;
}

+ (NSArray<DPromise *> *)allSignals
{
    return [self.allSignalsArray mapArray:^id(DWeakContainer<DPromise *> *container) {
        return container.value;
    }];
}

+ (void)setDebbugLogging:(BOOL)isDebbugLogging
{
    __dPromiseDebbugLogging = isDebbugLogging;
}

+ (void)addListedSignal:(DPromise *)signal
{
    @synchronized (self) {
        DWeakContainer *container = [DWeakContainer new];
        container.value = signal;
        [self.allSignalsArray addObject:container];
    }
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

@implementation DPromise (Operation)

+ (instancetype)newWithOperationQueuePriority:(NSOperationQueuePriority)priority block:(void (^)(DPromiseFullfillBlock))block
{
    DPromise *resultPromise = [DPromise newWithOperationQueuePriority:priority block:block disposingblock:nil];
    resultPromise.debugName = [self callStackName:0];
    return resultPromise;
}

+ (instancetype)newWithOperationQueuePriority:(NSOperationQueuePriority)priority block:(void (^)(DPromiseFullfillBlock))block disposingblock:(void (^)())disposingBlock
{
    if ( !block )
        return nil;
    DPromise *resultPromise = [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            block(fullfil);
        }];
        operation.queuePriority = priority;
        [operation start];
        __weak NSBlockOperation *_weakOpertion = operation;
        return ^{
            if ( _weakOpertion )
                [_weakOpertion cancel];
            
            if ( disposingBlock ) {
                disposingBlock();
            }
        };
    }];
    resultPromise.debugName = [self callStackName:0];
    return resultPromise;
}

@end

@implementation DPromise (ValueCheck)

- (id)thenWithValueClass:(Class)valueClass
               thenBlock:(id(^)(id))thenBlock
{
    return [self thenWithValueClass:valueClass thenBlock:thenBlock onQueue:dispatch_get_main_queue()];
}

- (id)thenOnBackgroundWithValueClass:(Class)valueClass
                           thenBlock:(id(^)(id))thenBlock
{
    return [self thenWithValueClass:valueClass thenBlock:thenBlock onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (id)thenWithValueClass:(Class)valueClass
               thenBlock:(id(^)(id))thenBlock
                 onQueue:(dispatch_queue_t)queue
{
    return [self then:^id(id nextValue) {
        return [nextValue isKindOfClass:valueClass] ? thenBlock(nextValue) : nextValue;
    } onQueue:queue];
}

- (id)thenOnCurrentThreadWithValueClass:(Class)valueClass
                              thenBlock:(id (^)(id))thenBlock
{
    return [self thenWithValueClass:valueClass thenBlock:thenBlock onQueue:_queue];
}

- (id)catchWithValueClass:(Class)valueClass
               catchBlock:(id(^)(NSError *))rejectErrorBlock
{
    return [self catchWithValueClass:valueClass catchBlock:rejectErrorBlock onQueue:dispatch_get_main_queue()];
}

- (id)catchOnBackgroundWithValueClass:(Class)valueClass
                           catchBlock:(id(^)(NSError *))rejectErrorBlock
{
    return [self catchWithValueClass:valueClass catchBlock:rejectErrorBlock onQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (id)catchWithValueClass:(Class)valueClass
               catchBlock:(id(^)(NSError *))rejectErrorBlock
                  onQueue:(dispatch_queue_t)queue
{
    return [self catch:^id(NSError *error) {
        return [error isKindOfClass:valueClass] ? rejectErrorBlock(error) : error;
    } onQueue:queue];
}

- (id)catchOnCurrentThreadWithValueClass:(Class)valueClass
                              catchBlock:(id(^)(NSError *))rejectErrorBlock
{
    return [self catchWithValueClass:valueClass catchBlock:rejectErrorBlock onQueue:_queue];
}

@end
