//
//  DPromise+ValueCheck.h
//  Cloudike
//
//  Created by Alexander Sviridov on 28.08.16.
//  Copyright © 2016 Advanced Software Development. All rights reserved.
//

#import "DPromise.h"

@interface DPromise<__covariant ObjectType> (ValueCheck)

- (id)thenWithValueClass:(Class)valueClass
               thenBlock:(id(^)(ObjectType))thenBlock;

- (id)thenOnBackgroundWithValueClass:(Class)valueClass
                           thenBlock:(id(^)(ObjectType))thenBlock;

- (id)thenWithValueClass:(Class)valueClass
               thenBlock:(id(^)(ObjectType))thenBlock
                 onQueue:(dispatch_queue_t)queue;

- (id)thenOnCurrentThreadWithValueClass:(Class)valueClass
                              thenBlock:(id (^)(id))thenBlock;

- (id)catchWithValueClass:(Class)valueClass
               catchBlock:(id(^)(NSError *))rejectErrorBlock;

- (id)catchOnBackgroundWithValueClass:(Class)valueClass
                           catchBlock:(id(^)(NSError *))rejectErrorBlock;

- (id)catchWithValueClass:(Class)valueClass
               catchBlock:(id(^)(NSError *))rejectErrorBlock
                  onQueue:(dispatch_queue_t)queue;

- (id)catchOnCurrentThreadWithValueClass:(Class)valueClass
                              catchBlock:(id(^)(NSError *))rejectErrorBlock;


@end
