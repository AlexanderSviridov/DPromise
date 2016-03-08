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

@interface DPromise<__covariant ObjectType> : NSObject

@property (readonly) BOOL isCompleated;
@property (copy) NSString *debugName;

+ (instancetype)newPromise:(DPromiseDisposable(^)(DPromiseFullfillBlock,DPromiseRejectBclock))block;
+ (instancetype)promiseWithValue:(id)value;
+ (instancetype)promiseWithError:(NSError *)error;

- (id)then:(DPromise *(^)(ObjectType))thenBlock;
- (id)thenOnBackground:(DPromise *(^)(ObjectType))thenBlock;
- (id)then:(DPromise *(^)(ObjectType))thenBlock onQueue:(dispatch_queue_t)queue;

- (id)catch:(DPromise *(^)(NSError *))rejectErrorBlock;

- (id)once;

- (void)dispose;

@end
