shader_type canvas_item;
// 방 바닥·천장 원근(#151). 장소 그림을 "평면 좌표(p = 세계 x) × 화면 줄(y)"로 그려 두고,
// 화면 줄마다 깊이 s(그 줄의 스크롤 빠르기)를 구해 그 줄을 s만큼 미끄러뜨려 읽는다.
//   바닥: y = vp_y + k·s  (s = 1이 하윤이 걷는 줄, s < 1은 벽 쪽 먼 줄, s > 1은 화면 앞)
//   천장: y = vp_y - k·s
// 화면 x = (p - 960)·s + 960 - cam_left·s  →  p = (X + cam_left·s - 960) / s + 960
// 판자 이음처럼 p가 같은 선은 걸을 때 소실점으로 모이며 돌아간다. cam_left는 RoomPerspective가 매 프레임 넣는다.

uniform sampler2D plane_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D glow_tex : filter_linear, repeat_disable;  // 창빛 웅덩이(같은 좌표, 작게): 나뭇잎 그림자로 일렁인다
uniform float cam_left = 0.0;
uniform float vp_y = 210.0;
uniform float k = 600.0;
uniform float dir = 1.0;          // 1 바닥, -1 천장
uniform float p0 = 0.0;           // 그림 왼쪽 끝의 p
uniform float p_width = 1.0;      // 그림 폭(p)
uniform float y0 = 0.0;           // 그림 맨 윗줄의 화면 y
uniform float rows = 1.0;         // 그림 높이(화면 줄)
uniform vec3 glow_color = vec3(1.0, 0.86, 0.6);
uniform float glow_strength = 0.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// 나뭇잎 그림자: 두 겹 잡음을 바람 쪽으로 흘려 덩어리로 자른다.
float leaves(vec2 p, float t) {
	float n = vnoise(p * 0.018 + vec2(t * 0.22, t * 0.07)) * 0.65 + vnoise(p * 0.05 - vec2(t * 0.4, 0.0)) * 0.35;
	return smoothstep(0.38, 0.62, n);
}

void fragment() {
	float y = world.y;
	float s = dir * (y - vp_y) / k;
	float X = world.x - cam_left;
	float p = (X + cam_left * s - 960.0) / max(s, 0.05) + 960.0;
	vec2 uv = vec2((p - p0) / p_width, (y - y0) / rows);
	vec4 c = texture(plane_tex, uv);
	if (glow_strength > 0.0) {
		float g = texture(glow_tex, uv).a;
		float lit = g * mix(0.45, 1.0, leaves(vec2(p, y * 3.0), TIME)) * glow_strength;
		c.rgb = 1.0 - (1.0 - c.rgb) * (1.0 - glow_color * lit);  // 스크린 섞기
	}
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		c.a = 0.0;
	}
	COLOR = c;
}
