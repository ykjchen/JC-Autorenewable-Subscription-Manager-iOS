//
//  SubscriptionManagerTests.m
//  SubscriptionManagerTests
//
//  Created by Joseph Chen on 11/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "JCLegacyReceiptVerifier.h"

@interface SubscriptionManagerTests : XCTestCase

@end

@implementation SubscriptionManagerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testHostName
{
    NSArray *inputs = [NSArray arrayWithObjects:
                       @"https://sandbox.itunes.apple.com/verifyReceipt",
                       @"http://sandbox.itunes.apple.com",
                       @"sandbox.itunes.apple.com", nil];
    NSString *expectedOutput = @"sandbox.itunes.apple.com";
    
    for (NSString *input in inputs) {
        NSString *hostname = [input hostName];
        XCTAssertEqualObjects(hostname, expectedOutput, @"Expected:%@ Got:%@", expectedOutput, hostname);
    }
}

@end
