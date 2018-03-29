//
//  Felix.m
//  Felix
//
//  Created by limboy on 13/03/2018.
//  Copyright © 2018 limboy. All rights reserved.
//

#import "Felix.h"
#import "Aspects.h"
#import <objc/runtime.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Felix_MD5)

- (NSString *)felix_MD5 {
    const char * pointer = [self UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(pointer, (CC_LONG)strlen(pointer), md5Buffer);
    
    NSMutableString *string = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [string appendFormat:@"%02x",md5Buffer[i]];
    
    return string;
}

@end

typedef struct {double d;} __FelixDouble__;
typedef struct {float f;} __FelixFloat__;

@implementation Felix
+ (Felix *)sharedInstance
{
    static Felix *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

+ (void)evalString:(NSString *)javascriptString
{
    [[self context] evaluateScript:javascriptString];
}

+ (void)evalEncryptedString:(NSString *)encryptedString
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encryptedString options:0];
    NSString *decryptedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSMutableString *reversedString = [NSMutableString stringWithCapacity:[decryptedString length]];
    
    [decryptedString enumerateSubstringsInRange:NSMakeRange(0,[decryptedString length])
                                        options:(NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences)
                                     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                         [reversedString appendString:substring];
                                     }];
    
    data = [[NSData alloc] initWithBase64EncodedString:reversedString options:0];
    decryptedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (decryptedString) {
        [self evalString:decryptedString];
    }
}

+ (void)evalEncryptedRemoteFile:(NSURL *)remoteURL md5Hash:(NSString *)md5Hash completion:(void (^)(NSError *))completion
{
    NSURLSessionTask *dataTask = [[NSURLSession sharedSession] dataTaskWithURL:remoteURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *calcuatedHash = [result felix_MD5];
            if ([calcuatedHash isEqualToString:md5Hash]) {
                [self evalEncryptedString:result];
                completion(nil);
            } else {
                completion([NSError errorWithDomain:[NSString stringWithFormat:@"invalid hash code, got: %@, expected: %@", calcuatedHash, md5Hash] code:-1 userInfo:nil]);
            }
        } else {
            completion(error);
        }
    }];
    
    [dataTask resume];
}

+ (JSContext *)context
{
    static JSContext *_context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _context = [[JSContext alloc] init];
        [_context setExceptionHandler:^(JSContext *context, JSValue *value) {
            NSLog(@"Oops: %@", value);
        }];
    });
    return _context;
}

+ (void)_fixWithMethod:(BOOL)isClassMethod aspectionOptions:(AspectOptions)option instanceName:(NSString *)instanceName selectorName:(NSString *)selectorName fixImpl:(JSValue *)fixImpl {
    Class klass = NSClassFromString(instanceName);
    if (isClassMethod) {
        klass = object_getClass(klass);
    }
    SEL sel = NSSelectorFromString(selectorName);
    [klass aspect_hookSelector:sel withOptions:option usingBlock:^(id<AspectInfo> aspectInfo){
        [fixImpl callWithArguments:@[aspectInfo.instance, aspectInfo.originalInvocation, aspectInfo.arguments]];
    } error:nil];
}

+ (void)_invocation:(NSInvocation *)invo signature:(NSMethodSignature *)sig setArgument:(id)obj atIndex:(NSInteger)index
{
    const char *argumentType = [sig getArgumentTypeAtIndex:index];
    switch (argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {
            // 对 primative 类型的处理下
#define __CALL_ARGTYPE_CASE(_typeString, _type, _selector) \
case _typeString: {                              \
_type value = [obj _selector];                     \
[invo setArgument:&value atIndex:index];\
break; \
}
            
            __CALL_ARGTYPE_CASE('c', char, charValue)
            __CALL_ARGTYPE_CASE('C', unsigned char, unsignedCharValue)
            __CALL_ARGTYPE_CASE('s', short, shortValue)
            __CALL_ARGTYPE_CASE('S', unsigned short, unsignedShortValue)
            __CALL_ARGTYPE_CASE('i', int, intValue)
            __CALL_ARGTYPE_CASE('I', unsigned int, unsignedIntValue)
            __CALL_ARGTYPE_CASE('l', long, longValue)
            __CALL_ARGTYPE_CASE('L', unsigned long, unsignedLongValue)
            __CALL_ARGTYPE_CASE('q', long long, longLongValue)
            __CALL_ARGTYPE_CASE('Q', unsigned long long, unsignedLongLongValue)
            __CALL_ARGTYPE_CASE('f', float, floatValue)
            __CALL_ARGTYPE_CASE('d', double, doubleValue)
            __CALL_ARGTYPE_CASE('B', BOOL, boolValue)
            
        default:
            [invo setArgument:&obj atIndex:index];
            break;
    }
}

+ (void)_invocation:(NSInvocation *)invo setReturnValue:(id)returnValue
{
    char returnType[255];
    strcpy(returnType, [invo.methodSignature methodReturnType]);
    
    // Restore the return type
    if (strcmp(returnType, @encode(__FelixDouble__)) == 0) {
        strcpy(returnType, @encode(double));
    }
    if (strcmp(returnType, @encode(__FelixFloat__)) == 0) {
        strcpy(returnType, @encode(float));
    }
    
    if (strncmp(returnType, "v", 1) != 0) {
        if (strncmp(returnType, "@", 1) == 0) {
            id _ret = [returnValue isKindOfClass:[JSValue class]] ? [returnValue toObject] : returnValue;
            [invo setReturnValue:&_ret];
            return;
        } else {
            switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
                    
#define __CALL_SETRETYPE_CASE(_typeString, _type, _selector) \
case _typeString: {                              \
_type value = [[returnValue toObject] _selector];                     \
[invo setReturnValue:&value];\
break; \
}
                    
                    __CALL_SETRETYPE_CASE('c', char, charValue)
                    __CALL_SETRETYPE_CASE('C', unsigned char, unsignedCharValue)
                    __CALL_SETRETYPE_CASE('s', short, shortValue)
                    __CALL_SETRETYPE_CASE('S', unsigned short, unsignedShortValue)
                    __CALL_SETRETYPE_CASE('i', int, intValue)
                    __CALL_SETRETYPE_CASE('I', unsigned int, unsignedIntValue)
                    __CALL_SETRETYPE_CASE('l', long, longValue)
                    __CALL_SETRETYPE_CASE('L', unsigned long, unsignedLongValue)
                    __CALL_SETRETYPE_CASE('q', long long, longLongValue)
                    __CALL_SETRETYPE_CASE('Q', unsigned long long, unsignedLongLongValue)
                    __CALL_SETRETYPE_CASE('f', float, floatValue)
                    __CALL_SETRETYPE_CASE('d', double, doubleValue)
                    __CALL_SETRETYPE_CASE('B', BOOL, boolValue)
            }
            return;
        }
    }
    NSLog(@"目前不支持设置除了 id 和 primative type 的其他类型数据");
}

+ (id)_target:(id)target
   isInstance:(BOOL)isInstance
performSelector:(NSString *)selector
   withObject:(id)obj1
   withObject:(id)obj2
   withObject:(id)obj3
   withObject:(id)obj4
   withObject:(id)obj5
{
    SEL _realSelector = NSSelectorFromString(selector);
    id _target = target;
    NSMethodSignature *sig;
    
    if (isInstance) {
        sig = [target methodSignatureForSelector:_realSelector];
    } else {
        _target = [NSClassFromString(target) class];
        sig = [_target methodSignatureForSelector:_realSelector];
    }
    if (!sig)
        return nil;
    
    NSInteger parametersCount = [selector componentsSeparatedByString:@":"].count - 1;
    
    NSInvocation* invo = [NSInvocation invocationWithMethodSignature:sig];
    [invo setTarget:_target];
    [invo setSelector:_realSelector];
    
    if (parametersCount >= 1) {
        [self _invocation:invo signature:sig setArgument:obj1 atIndex:2];
    }
    if (parametersCount >= 2) {
        [self _invocation:invo signature:sig setArgument:obj2 atIndex:3];
    }
    if (parametersCount >= 3) {
        [self _invocation:invo signature:sig setArgument:obj3 atIndex:4];
    }
    if (parametersCount >= 4) {
        [self _invocation:invo signature:sig setArgument:obj4 atIndex:5];
    }
    if (parametersCount >= 5) {
        [self _invocation:invo signature:sig setArgument:obj5 atIndex:6];
    }
    
    [invo invoke];
    
    if (sig.methodReturnLength) {
        char returnType[255];
        strcpy(returnType, [sig methodReturnType]);
        
        // Restore the return type
        if (strcmp(returnType, @encode(__FelixDouble__)) == 0) {
            strcpy(returnType, @encode(double));
        }
        if (strcmp(returnType, @encode(__FelixFloat__)) == 0) {
            strcpy(returnType, @encode(float));
        }
        
        id returnValue;
        if (strncmp(returnType, "v", 1) != 0) {
            if (strncmp(returnType, "@", 1) == 0) {
                void *result;
                [invo getReturnValue:&result];
                
                //For performance, ignore the other methods prefix with alloc/new/copy/mutableCopy
                if ([selector isEqualToString:@"alloc"] || [selector isEqualToString:@"new"] ||
                    [selector isEqualToString:@"copy"] || [selector isEqualToString:@"mutableCopy"]) {
                    returnValue = (__bridge_transfer id)result;
                } else {
                    returnValue = (__bridge id)result;
                }
                
                return returnValue;
            } else {
                switch (returnType[0] == 'r' ? returnType[1] : returnType[0]) {
                        
#define __CALL_RETYPE_CASE__(_typeString, _type) \
case _typeString: {                              \
_type tempResultSet; \
[invo getReturnValue:&tempResultSet];\
returnValue = @(tempResultSet); \
break; \
}
                        
                        __CALL_RETYPE_CASE__('c', char)
                        __CALL_RETYPE_CASE__('C', unsigned char)
                        __CALL_RETYPE_CASE__('s', short)
                        __CALL_RETYPE_CASE__('S', unsigned short)
                        __CALL_RETYPE_CASE__('i', int)
                        __CALL_RETYPE_CASE__('I', unsigned int)
                        __CALL_RETYPE_CASE__('l', long)
                        __CALL_RETYPE_CASE__('L', unsigned long)
                        __CALL_RETYPE_CASE__('q', long long)
                        __CALL_RETYPE_CASE__('Q', unsigned long long)
                        __CALL_RETYPE_CASE__('f', float)
                        __CALL_RETYPE_CASE__('d', double)
                        __CALL_RETYPE_CASE__('B', BOOL)
                }
                NSLog(@"目前不支持返回除了 id 和 primative type 的其他类型数据");
                return returnValue;
            }
        }
    }
    return nil;
}

+ (id)_class:(id)className performSelector:(NSString *)selector withObject:(id)obj1 withObject:(id)obj2 withObject:(id)obj3 withObject:(id)obj4 withObject:(id)obj5
{
    return [self _target:className isInstance:NO performSelector:selector withObject:obj1 withObject:obj2 withObject:obj3 withObject:obj4 withObject:obj5];
}

+ (id)_instance:(id)instance performSelector:(NSString *)selector withObject:(id)obj1 withObject:(id)obj2 withObject:(id)obj3 withObject:(id)obj4 withObject:(id)obj5
{
    return [self _target:instance isInstance:YES performSelector:selector withObject:obj1 withObject:obj2 withObject:obj3 withObject:obj4 withObject:obj5];
}



+ (void)fixIt
{
    [self context][@"fixInstanceMethod"] = ^(NSString *instanceName, NSString *selectorName, JSValue *fixImpl) {
        [self _fixWithMethod:NO aspectionOptions:AspectPositionInstead instanceName:instanceName selectorName:selectorName fixImpl:fixImpl];
    };
    
    [self context][@"fixClassMethod"] = ^(NSString *instanceName, NSString *selectorName, JSValue *fixImpl) {
        [self _fixWithMethod:YES aspectionOptions:AspectPositionInstead instanceName:instanceName selectorName:selectorName fixImpl:fixImpl];
    };
    
    [self context][@"callInstanceMethod"] = ^id(id instance, NSString *selectorName, id obj1, id obj2, id obj3, id obj4, id obj5) {
        return [self _instance:instance performSelector:selectorName withObject:obj1 withObject:obj2 withObject:obj3 withObject:obj4 withObject:obj5];
    };
    
    [self context][@"callClassMethod"] = ^id(NSString *className, NSString *selectorName, id obj1, id obj2, id obj3, id obj4, id obj5) {
        return [self _class:className performSelector:selectorName withObject:obj1 withObject:obj2 withObject:obj3 withObject:obj4 withObject:obj5];
    };
    
    [self context][@"invoke"] = ^(NSInvocation *invocation) {
        [invocation invoke];
    };
    
    [self context][@"setInvocationReturnValue"] = ^(NSInvocation *invocation, JSValue *returnValue) {
        [self _invocation:invocation setReturnValue:returnValue];
    };
    
    [self context][@"setInvocationParameter"] = ^(NSInvocation *invocation, NSInteger index, id value) {
        [self _invocation:invocation signature:invocation.methodSignature setArgument:value atIndex:index+2];
    };
    
    // helper
    [[self context] evaluateScript:@"var console = {}"];
    [self context][@"console"][@"log"] = ^(id message) {
        NSLog(@"Javascript log: %@",message);
    };
    
}
@end

