//
//  ChewyShader.metal
//  Mochimo
//
//  친구를 찹쌀떡처럼 주무르는 왜곡.
//
//  `distortionEffect`는 화면의 각 점이 **원래 그림의 어디를 가져올지**를 묻는다.
//  그래서 여기 식은 모두 거꾸로 쓴다. 늘어나 보이게 하려면 더 가까운 곳을,
//  눌려 보이게 하려면 더 먼 곳을 가져온다.
//
//   - squish  바닥을 축으로 위아래가 눌리고(1보다 작음) 늘어난다(1보다 큼).
//             부피를 지키려 옆이 그만큼 퍼지는데, 아래쪽 배가 가장 많이 퍼진다.
//             통째로 줄이는 것과 달리 무게가 아래로 쏠린 떡처럼 보인다.
//   - pull    잡은 자리 근처가 손가락 쪽으로 끌려 나온다. 바닥은 붙어 있다.
//   - dent    누른 자리가 오목하게 들어간다. 음수가 되면 볼록하게 부푼다.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 chewy(float2 position,
                              float2 base,
                              float bodyHeight,
                              float squish,
                              float2 touch,
                              float2 pull,
                              float dent,
                              float radius) {
    float2 source = position;

    // 바닥에서 잰 높이(위가 +)와 몸 안에서의 비율.
    float height = base.y - position.y;
    float t = clamp(height / bodyHeight, 0.0, 1.0);

    // 눌림 · 늘어남.
    float s = max(squish, 0.2);
    source.y = base.y - height / s;
    float belly = 0.55 + 0.45 * sin(3.14159 * clamp(t * 1.25, 0.0, 1.0));
    float widen = 1.0 + (1.0 / s - 1.0) * belly;
    source.x = base.x + (source.x - base.x) / widen;

    // 당김. 손가락에서 멀수록, 바닥에 가까울수록 덜 끌려온다.
    float2 fromTouch = position - touch;
    float reach = exp(-dot(fromTouch, fromTouch) / (2.0 * radius * radius));
    float lift = smoothstep(0.0, 0.55, t);
    source -= pull * reach * lift;

    // 콕 누름. 누른 자리 주변을 바깥에서 가져와 안쪽으로 모인 것처럼 보인다.
    float2 fromDent = source - touch;
    float press = exp(-dot(fromDent, fromDent) / (radius * radius * 0.45));
    source = touch + fromDent * (1.0 + dent * press);

    return source;
}
