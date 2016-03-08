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

- (void)testCreation
{
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    DPromise *newPromise = [DPromise newPromise:^MSPromiseDisposable(MSPromiseFullfillBlock fullfill, MSPromiseRejectBclock reject) {
        fullfill(@2);
        return nil;
    }];
    [[newPromise then:^id(NSNumber *value) {
        XCTAssertEqual(value, @2);
        return nil;
    }] then:^DPromise *(id value) {
        XCTAssertEqual(value, @2 );
        [expectation fulfill];
        return nil;
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

@end
