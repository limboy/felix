//
//  Felix.h
//  Felix
//
//  Created by limboy on 13/03/2018.
//  Copyright © 2018 limboy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

@interface Felix: NSObject
+ (void)fixIt;
+ (JSContext *)context;
+ (void)evalString:(NSString *)javascriptString;
// encrypt rule: base64encode(reverse(base64encode(jsstring)))
+ (void)evalEncryptedString:(NSString *)encryptedString;
+ (void)evalEncryptedRemoteFile:(NSURL *)remoteURL md5Hash:(NSString *)md5Hash completion:(void (^)(NSError *error))completion;
@end

