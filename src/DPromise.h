//
//  MSPromise.h
//  MySearch
//
//  Created by Alexander Sviridov on 30/11/15.
//  Copyright © 2015 Alexander Sviridov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DPromiseFullfillBlock)(id);
typedef void(^DPromiseDisposable)();

@interface DPromise<__covariant ObjectType> : NSObject {
    dispatch_queue_t _queue;
}

@property (readonly) BOOL isCompleated;
@property (copy) NSString *debugName;
@property BOOL repeatingLast;

+ (instancetype)newPromise:(DPromiseDisposable(^)(DPromiseFullfillBlock))block;
+ (instancetype)promiseWithValue:(id)value;
+ (instancetype)promiseWithError:(NSError *)error;

- (id)then:(id(^)(ObjectType))thenBlock;
- (id)thenOnBackground:(id(^)(ObjectType))thenBlock;
- (id)then:(id(^)(ObjectType))thenBlock onQueue:(dispatch_queue_t)queue;
- (id)thenOnCurrentThread:(id (^)(id))thenBlock;

- (instancetype)catch:(id(^)(NSError *))rejectErrorBlock;
- (instancetype)catchOnBackground:(id(^)(NSError *))rejectErrorBlock;
- (instancetype)catch:(id(^)(NSError *))rejectErrorBlock onQueue:(dispatch_queue_t)queue;
- (instancetype)catchOnCurrentThread:(id(^)(NSError *))rejectErrorBlock;

- (instancetype)once;

- (instancetype)finaly:(void(^)())block;

- (void)sendNext:(id)nextValue;

+ (DPromise<NSArray *> *)merge:(NSArray<DPromise *> *)mergingArray;

- (void)dispose;

@end

@interface DPromise<__covariant ObjType> (Operation)

+ (instancetype)newWithOperationQueuePriority:(NSOperationQueuePriority)priority block:(void(^)(DPromiseFullfillBlock))block;

+ (instancetype)newWithOperationQueuePriority:(NSOperationQueuePriority)priority block:(void(^)(DPromiseFullfillBlock))block disposingblock:(void(^)())disposingBlock;

@end

@interface DPromise<__covariant ObjectType> (ValueCheck)

- (id)thenWithValueClass:(Class)valueClass thenBlock:(id(^)(ObjectType))thenBlock;

- (id)thenOnBackgroundWithValueClass:(Class)valueClass thenBlock:(id(^)(ObjectType))thenBlock;

- (id)thenWithValueClass:(Class)valueClass thenBlock:(id(^)(ObjectType))thenBlock onQueue:(dispatch_queue_t)queue;

- (id)thenOnCurrentThreadWithValueClass:(Class)valueClass thenBlock:(id (^)(id))thenBlock;

- (id)catchWithValueClass:(Class)valueClass catchBlock:(id(^)(NSError *))rejectErrorBlock;

- (id)catchOnBackgroundWithValueClass:(Class)valueClass catchBlock:(id(^)(NSError *))rejectErrorBlock;

- (id)catchWithValueClass:(Class)valueClass catchBlock:(id(^)(NSError *))rejectErrorBlock onQueue:(dispatch_queue_t)queue;

- (id)catchOnCurrentThreadWithValueClass:(Class)valueClass catchBlock:(id(^)(NSError *))rejectErrorBlock;


@end

@interface DPromise (Debbug)

+ (NSArray<DPromise *> *)allSignals;
+ (void)setDebbugLogging:(BOOL)isDebbugLogging;

@end

