shader_type canvas_item;
// 풀잎 한 장(GrassField의 MultiMesh 인스턴스, #142). UV.y: 0 = 끝, 1 = 뿌리.
// INSTANCE_CUSTOM: r = 뿌리 x(노드 기준), g = 폭(px)×10의 정수부 + 흔들림 위상(소수부), b = 키(px), a = 뿌리 y(노드 기준).
// VERTEX는 인스턴스 변환(폭·키로 늘이기) 전의 풀잎 좌표(키 1, 폭 1)라, 픽셀로 구한 휨을 폭·키로 나눠 더한다.
// 바람은 왼쪽으로 분다(그림의 풀도 왼쪽으로 눕는다). 하윤 가까이 있는 풀은 하윤에게서 바깥으로 휜다.

uniform vec2 origin = vec2(0.0);          // 노드의 전역 자리
uniform float sway_px = 9.0;              // 평소 끝이 흔들리는 폭(키 120px 기준)
uniform float lean_px = 10.0;             // 늘 왼쪽으로 기운 정도
uniform float gust = 0.0;                 // 0~1 센 바람(게임이 올렸다 내린다)
uniform float wave_speed = 240.0;         // 바람 물결이 왼쪽으로 지나가는 빠르기(px/초)
uniform float wave_len = 1100.0;
uniform vec2 player_pos = vec2(-100000.0, 0.0);
uniform float push_radius = 120.0;
uniform float push_px = 70.0;

void vertex() {
	float bend = pow(1.0 - UV.y, 1.7);
	float wx = origin.x + INSTANCE_CUSTOM.r;
	float phase = fract(INSTANCE_CUSTOM.g) * 6.2832;
	float w = max(floor(INSTANCE_CUSTOM.g) / 10.0, 0.5);
	float h = max(INSTANCE_CUSTOM.b, 1.0);
	float k = h / 120.0;
	float sway = sin(TIME * 1.9 + phase + wx * 0.004) * 0.65 + sin(TIME * 0.8 + wx * 0.0017) * 0.35;
	float wave = smoothstep(0.35, 1.0, sin((wx + TIME * wave_speed) * 6.2832 / wave_len));
	float dx = (sway * sway_px - lean_px * (1.0 + wave * 1.6 + gust * 3.5)) * bend * k;
	// 하윤이 헤친다: 뿌리가 하윤 발 가까이(가로·세로) 있으면 바깥으로 휘고 조금 눌린다.
	float d = wx - player_pos.x;
	float near = 1.0 - smoothstep(push_radius * 0.25, push_radius, abs(d));
	near *= 1.0 - smoothstep(130.0, 220.0, abs(origin.y + INSTANCE_CUSTOM.a - player_pos.y));
	dx += sign(d) * near * push_px * bend * min(k, 1.6);
	VERTEX.x += dx / w;
	VERTEX.y += near * bend * 0.22;
}
