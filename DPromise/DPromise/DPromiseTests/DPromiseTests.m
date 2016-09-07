//
//  DPromiseTests.m
//  DPromiseTests
//
//  Created by Alexander Sviridov on 08.03.16.
//  Copyright © 2016 Alexander Sviridov. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DPromise.h"

@interface DPromiseTests : XCTestCase

@end

@implementation DPromiseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmptyChain {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    
    [[[[[DPromise promiseWithValue:@(2)] then:^id(NSNumber *value) {
        return value;
    }] then:^id(id value) {
        return value;
    }] catch:^id(NSError *error) {
        return nil;
    }] then:^id(NSNumber *number) {
        XCTAssertTrue([number isKindOfClass:[NSNumber class]]);
        XCTAssertEqual(number.intValue, 2);
        [expectation fulfill];
        return nil;
    }];
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testMerge {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    
    [[DPromise merge:@[[DPromise promiseWithValue:@(1)], [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            fullfil(@(2));
        });
        return nil;
    }], @(3), [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            fullfil(@(4));
        });
        return nil;
    }]]] then:^id(NSArray<NSNumber *> *results) {
        XCTAssertTrue([results isKindOfClass:[NSArray class]]);
        XCTAssertEqual(results.count, 4);
        XCTAssertEqual(results[0].intValue, 1);
        XCTAssertEqual(results[1].intValue, 2);
        XCTAssertEqual(results[2].intValue, 3);
        XCTAssertEqual(results[3].intValue, 4);
        [expectation fulfill];
        return results;
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testClassCheck {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    
    [[[[DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            fullfil(@"");
            fullfil(@(2));
        });
        return nil;
    }] then:^id(id value) {
        NSLog(@"valueClass %@", NSStringFromClass([value class]));
        return value;
    }] thenWithValueClass:[NSNumber class] thenBlock:^id(NSNumber *number) {
        NSLog(@"Number: %@ %@", number, NSStringFromClass([number class]));
        return number;
    }] thenWithValueClass:[NSString class] thenBlock:^id(NSString *string) {
        NSLog(@"string: %@ %@", string, NSStringFromClass([string class]));
        [expectation fulfill];
        return string;
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testCreation
{
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    DPromise *newPromise = [DPromise newPromise:^DPromiseDisposable(DPromiseFullfillBlock fullfill) {
        fullfill(@2);
        return nil;
    }];
    [[newPromise then:^id(NSNumber *value) {
        XCTAssertEqual(value, @2);
        return value;
    }] then:^DPromise *(id value) {
        XCTAssertEqual(value, @2 );
        [expectation fulfill];
        return value;
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

@end
