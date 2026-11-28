shader_type canvas_item;
// 천·잎이 바람에 살랑이게(#151): 커튼은 위가 고정(anchor 0), 나무 잎 덩어리는 아래가 고정(anchor 1).
// 붙은 쪽에서 멀수록 크게, 높이마다 박자가 조금씩 다르다. 그림 둘레에 amp만큼 빈 여백을 둔다
// (꼭짓점 넷짜리 네모라 꼭짓점을 옮기면 통째로 기울 뿐이라, 읽는 자리를 옮긴다).

uniform float amp = 6.0;        // px
uniform float speed = 1.2;
uniform float phase = 0.0;
uniform float anchor = 0.0;     // 0: 위가 고정, 1: 아래가 고정
uniform float ripple = 6.0;     // 높이에 따른 박자 차이(라디안, 위에서 아래까지)

varying vec4 tint;

void vertex() {
	tint = COLOR;  // fragment의 COLOR는 이미 그림 색을 곱한 값이라 꼭짓점 색을 따로 받는다
}

void fragment() {
	float w = anchor < 0.5 ? UV.y : 1.0 - UV.y;
	w = w * w;
	float t = TIME * speed + phase + UV.y * ripple;
	float dx = (sin(t) * 0.7 + sin(t * 2.3 + 1.7) * 0.3) * amp * w;
	vec2 uv = UV - vec2(dx * TEXTURE_PIXEL_SIZE.x, 0.0);
	COLOR = texture(TEXTURE, uv) * tint;
	if (uv.x < 0.0 || uv.x > 1.0) {
		COLOR.a = 0.0;
	}
}
