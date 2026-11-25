//
//  ObjCGuard.h
//  Mochimo
//
//  Objective-C 예외를 Swift 오류로 바꾼다.
//
//  AVFAudio 는 조건이 어긋나면 Swift 오류가 아니라 NSException 을 던진다 — 탭이 이미 걸린 버스에
//  또 걸 때, 형식이 하드웨어와 다를 때, 엔진이 멈춘 사이 플레이어를 켤 때. Swift 는 그것을 잡지
//  못해서 앱이 그대로 죽는다(2.1.4 · 2.1.5 진단이 모두 이 길이었다). 소리와 받아쓰기는 곁들이는
//  기능이라, 어긋나면 그 한 번을 조용히 넘기면 된다.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCGuard : NSObject

/// 블록을 돌리고, 그 안에서 NSException 이 나면 잡아 NSError 로 돌려준다.
/// Swift 에서는 `try ObjCGuard.perform { ... }`.
+ (BOOL)perform:(NS_NOESCAPE void (^)(void))block error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
