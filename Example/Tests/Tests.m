//
//  FelixTests.m
//  FelixTests
//
//  Created by limboy on 13/03/2018.
//  Copyright © 2018 limboy. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Felix.h"
#import <JavaScriptCore/JavaScriptCore.h>

@interface Flager:NSObject
+ (Flager *)sharedInstance;
@property (nonatomic) BOOL flaged;
@end

@implementation Flager

+ (Flager *)sharedInstance
{
    static Flager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[Flager alloc] init];
    });
    return _instance;
}

@end


@interface ClassSelectorDemo: NSObject
@end

@implementation ClassSelectorDemo
+ (void)noParameter
{
    [Flager sharedInstance].flaged = YES;
}

+ (void)oneParameter:(Flager *)param
{
    param.flaged = YES;
}

+ (id)oneParameterReturn:(NSString *)param
{
    NSLog(@"param:%@", param);
    return [NSString stringWithFormat:@"%@", param];
}

+ (Flager *)oneCustomeObjectParameter:(Flager *)param
{
    param.flaged = YES;
    return param;
}

+ (NSInteger)onePrimativeNumberParameterReturn:(NSInteger)param
{
    return param;
}

+ (BOOL)onePrimativeBooleanParameterReturn:(BOOL)param
{
    return param;
}

+ (NSString *)twoParameterReturn:(NSString *)param another:(NSInteger)another
{
    return [NSString stringWithFormat:@"%@%ld", param, (long)another];
}

@end




@interface InstanceSelectorDemo:NSObject

@end

@implementation InstanceSelectorDemo
- (void)noParameter
{
    [Flager sharedInstance].flaged = YES;
}

- (void)oneParameter:(Flager *)param
{
    param.flaged = YES;
}

- (id)oneParameterReturn:(NSString *)param
{
    return [NSString stringWithFormat:@"%@", param];
}

- (Flager *)oneCustomeObjectParameter:(Flager *)param
{
    param.flaged = YES;
    return param;
}

- (NSInteger)onePrimativeNumberParameterReturn:(NSInteger)param
{
    return param;
}

- (BOOL)onePrimativeBooleanParameterReturn:(BOOL)param
{
    return param;
}

- (NSString *)twoParameterReturn:(NSString *)param another:(NSInteger)another
{
    return [NSString stringWithFormat:@"%@%ld", param, (long)another];
}
@end



@interface FelixTests : XCTestCase

@end

@implementation FelixTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Felix fixIt];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRemoteURL {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"wait"];
    [Felix evalEncryptedRemoteFile:[NSURL URLWithString:@"https://s3.mogucdn.com/mlcdn/c45406/180328_7cbd15bdfa6giceii98d7lf8jga59.txt"] md5Hash:@"e1f26a884535e5eecef4ed2bdbfb6dde" completion:^(NSError *error) {
        if (!error) {
            XCTAssert([[NSUserDefaults standardUserDefaults] boolForKey:@"foobar"]);
        } else {
            XCTFail(@"load faile: %@", error);
        }
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10];
}

- (void)testEncryptedString {
    [Felix evalEncryptedString:@"PXNUS25JWFlpOTJibWRDSXNVV2R5UkhJc2NpTzVWMlN5OW1aNncyYnZKRWRsTjNKZ3dDZHNWM2NsSkhLazlHYTBWV1RsTm1iaFIzY3VsRWJzRjJZZ3NUS25NSGRzVlhZbVZHUnlWMmNWUm1jaFJtYmhSM2NuQUNMbk1IZHNWWFltVkdSeVYyY1ZObFRuZ0NadmhHZGwxMGN6RkdiRHhHYmhOR0k5QUNkc1YzY2xKSEl5Rm1k"];
    XCTAssert([[NSUserDefaults standardUserDefaults] boolForKey:@"foobar"]);
}

- (void)testCallClassMethod {
    [Flager sharedInstance].flaged = NO;
    [Felix evalString:@"callClassMethod('ClassSelectorDemo', 'noParameter');"];
    XCTAssert([Flager sharedInstance].flaged);
}

- (void)testCallClassMethodOneParameter {
    [Felix evalString:@"var result = callClassMethod('ClassSelectorDemo', 'oneParameterReturn:', 'yoyo');"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([[result toString] isEqualToString:@"yoyo"]);
    
    [Felix evalString:@"var flager = callClassMethod('Flager', 'new'); callClassMethod('ClassSelectorDemo', 'oneParameter:', flager);"];
    JSValue *flager = [Felix context][@"flager"];
    XCTAssert(((Flager *)[flager toObject]).flaged);
}

- (void)testCallClassMethodCustomObjectParameter {
    [Felix evalString:@"var flager = callClassMethod('Flager', 'new'); var result = callClassMethod('ClassSelectorDemo', 'oneCustomeObjectParameter:', flager);"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert(((Flager *)[result toObject]).flaged);
}

- (void)testCallClassMethodOnePrimativeParameter {
    [Felix evalString:@"var result = callClassMethod('ClassSelectorDemo', 'onePrimativeNumberParameterReturn:', 3);"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([result toInt32] == 3);
    
    [Felix evalString:@"var result1 = callClassMethod('ClassSelectorDemo', 'onePrimativeBooleanParameterReturn:', true)"];
    JSValue *result1 = [Felix context][@"result1"];
    XCTAssert([result1 toBool]);
}

- (void)testCallClassMethodTwoParameters {
    [Felix evalString:@"var result = callClassMethod('ClassSelectorDemo', 'twoParameterReturn:another:', 'day', 123)"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([[result toString] isEqualToString:@"day123"]);
}


- (void)testCallInstanceMethod {
    [Flager sharedInstance].flaged = NO;
    [Felix evalString:@"var demo = callClassMethod('InstanceSelectorDemo', 'new'); callInstanceMethod(demo, 'noParameter');"];
    XCTAssert([Flager sharedInstance].flaged);
}

- (void)testCallInstanceMethodOneParameter {
    [Felix evalString:@"var demo = callClassMethod('InstanceSelectorDemo', 'new'); var result = callInstanceMethod(demo, 'oneParameterReturn:', 'yoyo');"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([[result toString] isEqualToString:@"yoyo"]);
    
    [Felix evalString:@"var flager = callClassMethod('Flager', 'new'); callInstanceMethod(demo, 'oneParameter:', flager);"];
    JSValue *flager = [Felix context][@"flager"];
    XCTAssert(((Flager *)[flager toObject]).flaged);
}

- (void)testCallInstanceMethodCustomObjectParameter {
    [Felix evalString:@"var demo = callClassMethod('InstanceSelectorDemo', 'new');var flager = callClassMethod('Flager', 'new'); var result = callInstanceMethod(demo, 'oneCustomeObjectParameter:', flager);"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert(((Flager *)[result toObject]).flaged);
}

- (void)testCallInstanceMethodOnePrimativeParameter {
    [Felix evalString:@"var demo = callClassMethod('InstanceSelectorDemo', 'new');var result = callInstanceMethod(demo, 'onePrimativeNumberParameterReturn:', 3);"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([result toInt32] == 3);
    
    [Felix evalString:@"var result1 = callInstanceMethod(demo, 'onePrimativeBooleanParameterReturn:', true)"];
    JSValue *result1 = [Felix context][@"result1"];
    XCTAssert([result1 toBool]);
}

- (void)testCallInstanceMethodTwoParameters {
    [Felix evalString:@"var demo = callClassMethod('InstanceSelectorDemo', 'new'); var result = callInstanceMethod(demo, 'twoParameterReturn:another:', 'day', 123)"];
    JSValue *result = [Felix context][@"result"];
    XCTAssert([[result toString] isEqualToString:@"day123"]);
}

- (void)testReplaceClassSelectorReturnValue {
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'oneParameterReturn:', function(instance, invo) {invoke(invo); setInvocationReturnValue(invo, 'replaced');})"];
    
    NSString *result = [ClassSelectorDemo oneParameterReturn:@"yes"];
    XCTAssert([result isEqualToString:@"replaced"]);
    
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'onePrimativeNumberParameterReturn:', function(instance, invo){invoke(invo); setInvocationReturnValue(invo, 42);})"];
    
    NSInteger _result = [ClassSelectorDemo onePrimativeNumberParameterReturn:1];
    XCTAssert(_result == 42);
    
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'onePrimativeBooleanParameterReturn:', function(instance, invo){invoke(invo); setInvocationReturnValue(invo, false);})"];
    
    BOOL __result = [ClassSelectorDemo onePrimativeBooleanParameterReturn:YES];
    XCTAssert(!__result);
    
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'oneCustomeObjectParameter:', function(instance, invo){invoke(invo); var obj = callClassMethod('Flager', 'new'); setInvocationReturnValue(invo, obj);})"];
    
    Flager *flager = [Flager new];
    Flager *___result = [ClassSelectorDemo oneCustomeObjectParameter:flager];
    XCTAssert(!___result.flaged);
}

- (void)testReplaceClassParameter {
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'oneParameterReturn:', function(instance, invo) {setInvocationParameter(invo, 0, 'replaced'); invoke(invo);})"];
    
    NSString *result = [ClassSelectorDemo oneParameterReturn:@"yes"];
    XCTAssert([result isEqualToString:@"replaced"]);
    
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'onePrimativeNumberParameterReturn:', function(instance, invo){setInvocationParameter(invo, 0, 42); invoke(invo);})"];
    
    NSInteger _result = [ClassSelectorDemo onePrimativeNumberParameterReturn:1];
    XCTAssert(_result == 42);
    
    [Felix evalString:@"fixClassMethod('ClassSelectorDemo', 'onePrimativeBooleanParameterReturn:', function(instance, invo){setInvocationParameter(invo, 0, false); invoke(invo);})"];
    
    BOOL __result = [ClassSelectorDemo onePrimativeBooleanParameterReturn:YES];
    XCTAssert(!__result);
}

- (void)testCallOriginClassSelector {
    [Felix evalString:@"var triggered = false; fixClassMethod('ClassSelectorDemo', 'oneParameter:', function(instance, invo){triggered = true; invoke(invo);})"];
    
    [Felix evalString:@"var _triggered = false; fixClassMethod('ClassSelectorDemo', 'noParameter', function(instance, invo){_triggered = true; invoke(invo);})"];
    
    Flager *flager = [Flager new];
    [ClassSelectorDemo oneParameter:flager];
    XCTAssert(flager.flaged);
    JSValue *result = [Felix context][@"triggered"];
    XCTAssert([result toBool]);
    
    [ClassSelectorDemo noParameter];
    XCTAssert([Flager sharedInstance].flaged);
    JSValue *_result = [Felix context][@"_triggered"];
    XCTAssert([_result toBool]);
}

- (void)testReplaceInstanceSelectorReturnValue {
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'oneParameterReturn:', function(instance, invo) {invoke(invo); setInvocationReturnValue(invo, 'replaced');})"];
    
    NSString *result = [[InstanceSelectorDemo new] oneParameterReturn:@"yes"];
    XCTAssert([result isEqualToString:@"replaced"]);
    
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'onePrimativeNumberParameterReturn:', function(instance, invo){invoke(invo); setInvocationReturnValue(invo, 42);})"];
    
    NSInteger _result = [[InstanceSelectorDemo new] onePrimativeNumberParameterReturn:1];
    XCTAssert(_result == 42);
    
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'onePrimativeBooleanParameterReturn:', function(instance, invo){invoke(invo); setInvocationReturnValue(invo, false);})"];
    
    BOOL __result = [[InstanceSelectorDemo new] onePrimativeBooleanParameterReturn:YES];
    XCTAssert(!__result);
    
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'oneCustomeObjectParameter:', function(instance, invo){invoke(invo); var obj = callClassMethod('Flager', 'new'); setInvocationReturnValue(invo, obj);})"];
    
    Flager *flager = [Flager new];
    Flager *___result = [[InstanceSelectorDemo new] oneCustomeObjectParameter:flager];
    XCTAssert(!___result.flaged);
}

- (void)testReplaceInstanceParameter {
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'oneParameterReturn:', function(instance, invo) {setInvocationParameter(invo, 0, 'replaced'); invoke(invo);})"];
    
    NSString *result = [[InstanceSelectorDemo new] oneParameterReturn:@"yes"];
    XCTAssert([result isEqualToString:@"replaced"]);
    
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'onePrimativeNumberParameterReturn:', function(instance, invo){setInvocationParameter(invo, 0, 42); invoke(invo);})"];
    
    NSInteger _result = [[InstanceSelectorDemo new] onePrimativeNumberParameterReturn:1];
    XCTAssert(_result == 42);
    
    [Felix evalString:@"fixInstanceMethod('InstanceSelectorDemo', 'onePrimativeBooleanParameterReturn:', function(instance, invo){setInvocationParameter(invo, 0, false); invoke(invo);})"];
    
    BOOL __result = [[InstanceSelectorDemo new] onePrimativeBooleanParameterReturn:YES];
    XCTAssert(!__result);
}

- (void)testCallOriginInstanceSelector {
    [Felix evalString:@"var triggered = false; fixInstanceMethod('InstanceSelectorDemo', 'oneParameter:', function(instance, invo){triggered = true; invoke(invo);})"];
    
    [Felix evalString:@"var _triggered = false; fixInstanceMethod('InstanceSelectorDemo', 'noParameter', function(instance, invo){_triggered = true; invoke(invo);})"];
    
    Flager *flager = [Flager new];
    InstanceSelectorDemo *demo = [InstanceSelectorDemo new];
    
    [demo oneParameter:flager];
    XCTAssert(flager.flaged);
    JSValue *result = [Felix context][@"triggered"];
    XCTAssert([result toBool]);
    
    [Flager sharedInstance].flaged = FALSE;
    InstanceSelectorDemo *demo1 = [InstanceSelectorDemo new];
    [demo1 noParameter];
    XCTAssert([Flager sharedInstance].flaged);
    JSValue *_result = [Felix context][@"_triggered"];
    XCTAssert([_result toBool]);
}

@end
