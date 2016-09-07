//
//  RSCollections.h
//  POS
//
//  Created by Alexander Sviridov on 11/01/16.
//
//

#import <Foundation/Foundation.h>

@interface DCollectionPair<__covariant KeyType, __covariant ObjectType> : NSObject

@property KeyType key;
@property ObjectType value;

+ (instancetype)pairWithKey:(KeyType)key value:(ObjectType)value;

@end

@interface NSArray<__covariant ObjectType> (DCollections)

- (NSArray *)mapArray:(id(^)(ObjectType))mappingBlock;
- (NSDictionary *)mapDictionary:(DCollectionPair *(^)(ObjectType))mappingBlock;
+ (NSArray *)arrayFromRange:(NSRange)range;
- (NSArray *)flattern;
- (NSArray *)flatternMapArray:(id(^)(ObjectType))mappingBlock;

- (id)reduceWithValue:(id)value block:(id(^)(id reducingValue, ObjectType collectionValue))block;

@end

@interface NSDictionary (DCollections)

- (NSArray *)mapArray:(id(^)(DCollectionPair *))mappingBlock;
- (NSArray *)flatternMapArray:(id(^)(DCollectionPair *))mappingBlock;
- (NSDictionary *)mapDictionary:(DCollectionPair *(^)(DCollectionPair *))mappingBlock;

@end
