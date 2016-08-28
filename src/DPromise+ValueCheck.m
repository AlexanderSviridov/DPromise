//
//  DPromise+ValueCheck.m
//  Cloudike
//
//  Created by Alexander Sviridov on 28.08.16.
//  Copyright © 2016 Advanced Software Development. All rights reserved.
//

#import "DPromise+ValueCheck.h"

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
