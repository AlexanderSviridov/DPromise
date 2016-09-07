//
//  RSCollections.m
//  POS
//
//  Created by Alexander Sviridov on 11/01/16.
//
//

#import "DCollections.h"

@implementation DCollectionPair

+ (instancetype)pairWithKey:(id)key value:(id)value
{
    DCollectionPair *result = [self new];
    result.key = key;
    result.value = value;
    return result;
}

@end

@implementation NSArray (DCollections)

- (NSArray *)mapArray:(id (^)(id))mappingBlock
{
    if ( !mappingBlock )
    {
        return nil;
    }
    
    NSMutableArray *arr = [NSMutableArray new];
    
    for ( id item in self )
    {
        id newItem = mappingBlock(item);
        if ( newItem )
        {
            [arr addObject:newItem];
        }
    }
    
    return [NSArray arrayWithArray:arr];
}

- (NSArray *)flattern
{
    
    NSMutableArray *arr = [NSMutableArray new];
    
    for ( id item in self )
    {
        if ( [item isKindOfClass:[NSArray class]] )
        {
            [arr addObjectsFromArray:item];
            continue;
        }
        [arr addObject:item];
        
    }
        
    return [NSArray arrayWithArray:arr];
}

- (NSArray *)flatternMapArray:(id (^)(id))mappingBlock
{
    if ( !mappingBlock )
    {
        return nil;
    }
    
    NSMutableArray *arr = [NSMutableArray new];
    
    for ( id item in self )
    {
        id newItem = mappingBlock(item);
        if ( !newItem )
        {
            continue;
        }
        if ( [newItem isKindOfClass:[NSArray class]] )
        {
            [arr addObjectsFromArray:newItem];
            continue;
        }
        [arr addObject:newItem];
    }
    
    return [NSArray arrayWithArray:arr];
}

- (NSDictionary *)mapDictionary:(DCollectionPair *(^)(id))mappingBlock
{
    if ( !mappingBlock )
    {
        return nil;
    }
    
    NSMutableDictionary *result = [NSMutableDictionary new];
    
    for ( id item in self )
    {
        DCollectionPair *newPair = mappingBlock(item);
        if ( newPair && newPair.key )
        {
            [result setObject:newPair.value forKey:newPair.key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:result];
}

+ (NSArray *)arrayFromRange:(NSRange)range
{
    NSMutableArray *arr = [NSMutableArray new];
    
    for ( NSInteger i = range.location; i < range.length + range.location; ++i )
    {
        [arr addObject:@(i)];
    }
    
    return [NSArray arrayWithArray:arr];
}

- (id)reduceWithValue:(id)value block:(id (^)(id, id))block
{
    if ( !block || !value ) {
        return nil;
    }
    id resultValue = value;
    for (id collectionValue in self) {
        resultValue = block(resultValue, collectionValue);
    }
    return resultValue;
}

@end

@implementation NSDictionary (DCollections)

- (NSArray *)mapArray:(id (^)(DCollectionPair *))mappingBlock
{
    if ( !mappingBlock )
        return nil;
    NSMutableArray *result = [NSMutableArray new];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        id resultValue = mappingBlock([DCollectionPair pairWithKey:key value:obj]);
        if ( resultValue )
        {
            [result addObject:resultValue];
        }
    }];
    return [NSArray arrayWithArray:result];
}

- (NSArray *)flatternMapArray:(id (^)(DCollectionPair *))mappingBlock
{
    if ( !mappingBlock )
        return nil;
    NSMutableArray *result = [NSMutableArray new];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        id resultValue = mappingBlock([DCollectionPair pairWithKey:key value:obj]);
        if ( !resultValue )
            return;
        if ( [resultValue isKindOfClass:[NSArray class]] )
        {
            [result addObjectsFromArray:resultValue];
            return;
        }
        [result addObject:resultValue];
    }];
    return [NSArray arrayWithArray:result];
}

- (NSDictionary *)mapDictionary:(DCollectionPair *(^)(DCollectionPair *))mappingBlock
{
    if ( !mappingBlock )
        return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        DCollectionPair *resultPair = mappingBlock([DCollectionPair pairWithKey:key value:obj]);
        if ( resultPair && resultPair.key )
        {
            [result setObject:resultPair.value forKey:resultPair.key];
        }
    }];
    return [NSDictionary dictionaryWithDictionary:result];
}

@end
