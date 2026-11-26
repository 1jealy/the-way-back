shader_type canvas_item;
// 색연필 질감(#117 뒤): 지도 위에 코드가 긋는 선(길·동그라미·체크)에 건다.
// 종이 결(가는 알갱이)에 걸려 군데군데 비고, 한 방향으로 긁힌 결이 남는다. 결은 화면이 아니라 지도 좌표에 붙는다.
// 선 가장자리일수록(덜 칠해진 곳) 많이 빈다. 색은 칠이 진한 곳에서 조금 더 짙다.

uniform float grain_scale = 0.55;   // 종이 알갱이 크기(작을수록 굵다)
uniform float streak_angle = 0.62;  // 긁힌 결 방향(라디안)
uniform float coverage = 0.62;      // 칠해지는 비율(1이면 거의 꽉 찬다)

varying vec2 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 d = vec2(cos(streak_angle), sin(streak_angle));
	vec2 n = vec2(-d.y, d.x);
	float tooth = noise(local_pos * grain_scale);
	tooth = tooth * 0.6 + noise(local_pos * grain_scale * 2.3 + 17.0) * 0.4;
	// 긁힌 결: 결 방향으로 길게, 가로로는 촘촘하게
	float streak = noise(vec2(dot(local_pos, d) * 0.045, dot(local_pos, n) * 0.85));
	float paper = tooth * 0.65 + streak * 0.35;
	float a = COLOR.a;
	// 칠이 옅은 곳(가장자리)일수록 문턱이 높아 더 빈다
	float th = 1.0 - coverage * (0.55 + 0.45 * a);
	float ink = smoothstep(th - 0.12, th + 0.12, paper);
	COLOR.rgb *= 0.9 + 0.2 * (1.0 - paper);
	COLOR.a = a * mix(0.25, 1.0, ink);
}
