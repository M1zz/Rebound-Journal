//
//  ObjCGuard.m
//  Mochimo
//

#import "ObjCGuard.h"

@implementation ObjCGuard

+ (BOOL)perform:(NS_NOESCAPE void (^)(void))block error:(NSError * _Nullable * _Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.leeo.ReboundJournal.ObjCGuard"
                                         code:1
                                     userInfo:@{
                NSLocalizedDescriptionKey: exception.reason ?: exception.name,
                @"exceptionName": exception.name,
            }];
        }
        return NO;
    }
}

@end
