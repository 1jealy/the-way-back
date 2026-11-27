shader_type canvas_item;
// 풀잎 한 장(GrassField의 MultiMesh 인스턴스, #142). UV.y: 0 = 끝, 1 = 뿌리.
// INSTANCE_CUSTOM: r = 뿌리 x(노드 기준), g = 폭(px)×10의 정수부 + 흔들림 위상(소수부), b = 키(px), a = 뿌리 y(노드 기준).
// VERTEX는 인스턴스 변환(폭·키로 늘이기) 전의 풀잎 좌표(키 1, 폭 1)라, 픽셀로 구한 휨을 폭·키로 나눠 더한다.
// 끝이 옆으로 가는 만큼 내려와 풀잎이 늘어나지 않고 휘어 보인다.
// 바람은 왼쪽으로 분다(그림의 풀도 왼쪽으로 눕는다). 하윤 가까이 있는 풀은 하윤에게서 비켜 눕고,
// 지나간 자리는 출렁이며 돌아온다(player_vel이 있을 때 하윤 뒤쪽).

uniform vec2 origin = vec2(0.0);          // 노드의 전역 자리
uniform float sway_px = 9.0;              // 평소 끝이 흔들리는 폭(키 120px 기준)
uniform float lean_px = 9.0;              // 늘 왼쪽으로 기운 정도
uniform float gust = 0.0;                 // 0~1 센 바람(게임이 올렸다 내린다)
uniform float wave_speed = 240.0;         // 바람 물결이 왼쪽으로 지나가는 빠르기(px/초)
uniform float wave_len = 1100.0;
uniform vec2 player_pos = vec2(-100000.0, 0.0);
uniform float player_vel = 0.0;           // 하윤이 걷는 빠르기(px/초, 부호는 방향)
uniform float push_radius = 120.0;
uniform float push_px = 40.0;

void vertex() {
	float bend = pow(1.0 - UV.y, 1.7);
	float wx = origin.x + INSTANCE_CUSTOM.r;
	float phase = fract(INSTANCE_CUSTOM.g) * 6.2832;
	float w = max(floor(INSTANCE_CUSTOM.g) / 10.0, 0.5);
	float h = max(INSTANCE_CUSTOM.b, 1.0);
	float k = h / 120.0;
	float sway = sin(TIME * 1.9 + phase + wx * 0.004) * 0.65 + sin(TIME * 0.8 + wx * 0.0017) * 0.35;
	float wave = smoothstep(0.35, 1.0, sin((wx + TIME * wave_speed) * 6.2832 / wave_len));
	float tip = (sway * sway_px - lean_px * (1.0 + wave * 1.6 + gust * 3.5)) * k;
	// 하윤이 헤친다: 가까울수록 크게 비켜 눕는다(가우스 — 가운데가 비지 않게).
	float d = wx - player_pos.x;
	float rel = d / push_radius;
	float near = exp(-rel * rel * 2.2);
	near *= 1.0 - smoothstep(130.0, 220.0, abs(origin.y + INSTANCE_CUSTOM.a - player_pos.y));
	float side = d / (abs(d) + 18.0);  // 바로 앞의 풀은 덜 갈라진다
	tip += side * near * push_px * min(k, 1.8);
	// 지나간 자리: 하윤 뒤쪽 풀이 출렁이며 돌아온다.
	float moving = clamp(abs(player_vel) / 300.0, 0.0, 1.0);
	float behind = -d * sign(player_vel);
	float wake = step(0.0, behind) * exp(-behind / 170.0) * sin(behind * 0.05 - TIME * 9.0) * moving;
	wake *= 1.0 - smoothstep(130.0, 220.0, abs(origin.y + INSTANCE_CUSTOM.a - player_pos.y));
	tip += wake * 14.0 * min(k, 1.8);
	float dx = tip * bend;
	float dy = (tip * tip) / (2.0 * h) * bend;  // 옆으로 간 만큼 끝이 내려온다(휘기)
	VERTEX.x += dx / w;
	VERTEX.y += dy / h;
}
