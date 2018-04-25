## 这是什么

一个基于 Aspects 的轻量级 iOS Hotfix，核心原理是结合 `Aspects` 自带的动态替换方法加上 OC 原生的动态调用方法的能力，通过 `JSCore` 作为 Bridge 来达到效果。

## 特点
* 基于 `Aspects`，降低审核风险（`Aspects`已在上百款 App 使用），我自己也测试过可以通过审核。
* 没有 JS 中间层，直接使用 OC 暴露给 JS 的方法。
* 只支持 id 和 primative 类型的数据。
* 所有的方法都有 test case 覆盖 (详见 `Tests.m` )。

仅作为发生「线上 App 有大问题，又不想发版」时的一个备选项。

## Demo

更多用法参见 `Tests.m`

Replace Class Selector Return Value

```objc
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
```
