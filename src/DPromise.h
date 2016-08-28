//
//  MSPromise.h
//  MySearch
//
//  Created by Alexander Sviridov on 30/11/15.
//  Copyright © 2015 Alexander Sviridov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DPromiseFullfillBlock)(id);
typedef void(^DPromiseRejectBclock)(NSError *);
typedef void(^DPromiseDisposable)();

@interface DPromise<__covariant ObjectType> : NSObject {
    dispatch_queue_t _queue;
}

@property (readonly) BOOL isCompleated;
@property (copy) NSString *debugName;

+ (instancetype)newPromise:(DPromiseDisposable(^)(DPromiseFullfillBlock,DPromiseRejectBclock))block;
+ (instancetype)promiseWithValue:(id)value;
+ (instancetype)promiseWithError:(NSError *)error;

- (id)then:(id(^)(ObjectType))thenBlock;
- (id)thenOnBackground:(id(^)(ObjectType))thenBlock;
- (id)then:(id(^)(ObjectType))thenBlock onQueue:(dispatch_queue_t)queue;
- (id)thenOnCurrentThread:(id (^)(id))thenBlock;

- (id)catch:(id(^)(NSError *))rejectErrorBlock;
- (id)catchOnBackground:(id(^)(NSError *))rejectErrorBlock;
- (id)catch:(id(^)(NSError *))rejectErrorBlock onQueue:(dispatch_queue_t)queue;
- (id)catchOnCurrentThread:(id(^)(NSError *))rejectErrorBlock;

- (id)once;

+ (DPromise<NSArray *> *)merge:(NSArray<DPromise *> *)mergingArray;

- (void)dispose;

@end
