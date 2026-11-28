shader_type canvas_item;
// 화면 전체 필터(#151 시험): 그린 배경·인물을 한 그림처럼 묶는다. 세계(층 0) 위, UI(Overlay 10) 아래에 둔다.
//   paint   : 쿠와하라(Kuwahara) 붓 터치 — 네 칸 중 고른(분산이 작은) 칸의 평균. 가장자리는 살리고 면은 물감처럼 뭉갠다
//   grade   : 색 보정 — 그늘은 보랏빛, 밝은 곳은 꿀빛, 채도·대비
//   bloom   : 밝은 곳이 번진다(창빛·촛불)
//   paper   : 종이 결(가는 결 + 얼룩)
//   edge    : 윤곽을 연필선처럼 조금 어둡게

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float paint_radius = 0.0;     // 0이면 끔. 3~5
uniform float grade = 0.0;            // 0~1
uniform vec3 shadow_tint = vec3(0.42, 0.34, 0.55);
uniform vec3 light_tint = vec3(1.0, 0.86, 0.62);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float bloom = 0.0;            // 0~1
uniform float paper = 0.0;            // 0~1
uniform float edge = 0.0;             // 0~1

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 kuwahara(vec2 uv, vec2 px, int r) {
	vec3 m[4]; vec3 s[4];
	for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); }
	ivec2 off[4] = ivec2[](ivec2(-r, -r), ivec2(0, -r), ivec2(-r, 0), ivec2(0, 0));
	float n = float((r + 1) * (r + 1));
	for (int k = 0; k < 4; k++) {
		for (int j = 0; j <= r; j++) {
			for (int i = 0; i <= r; i++) {
				vec3 c = textureLod(screen, uv + vec2(float(off[k].x + i), float(off[k].y + j)) * px, 0.0).rgb;
				m[k] += c; s[k] += c * c;
			}
		}
	}
	float best = 1e9; vec3 outc = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 mean = m[k] / n;
		vec3 v = abs(s[k] / n - mean * mean);
		float sv = v.r + v.g + v.b;
		if (sv < best) { best = sv; outc = mean; }
	}
	return outc;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = paint_radius > 0.5 ? kuwahara(uv, px, int(paint_radius)) : textureLod(screen, uv, 0.0).rgb;
	if (edge > 0.0) {
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		float lx = dot(textureLod(screen, uv + vec2(px.x * 1.5, 0), 0.0).rgb - textureLod(screen, uv - vec2(px.x * 1.5, 0), 0.0).rgb, vec3(0.33));
		float ly = dot(textureLod(screen, uv + vec2(0, px.y * 1.5), 0.0).rgb - textureLod(screen, uv - vec2(0, px.y * 1.5), 0.0).rgb, vec3(0.33));
		float e = smoothstep(0.08, 0.35, length(vec2(lx, ly)));
		c = mix(c, c * vec3(0.55, 0.42, 0.36), e * edge);
	}
	if (bloom > 0.0) {
		vec3 b = textureLod(screen, uv, 3.5).rgb + textureLod(screen, uv, 5.0).rgb;
		b *= 0.5;
		b = max(b - 0.62, 0.0) * 2.2;
		c = 1.0 - (1.0 - c) * (1.0 - b * bloom * light_tint);
	}
	if (grade > 0.0) {
		float l = dot(c, vec3(0.3, 0.59, 0.11));
		vec3 g = c;
		g = mix(g, g * shadow_tint * 1.6, (1.0 - smoothstep(0.0, 0.45, l)) * 0.5);
		g = mix(g, 1.0 - (1.0 - g) * (1.0 - light_tint * 0.35), smoothstep(0.55, 1.0, l));
		g = mix(vec3(dot(g, vec3(0.3, 0.59, 0.11))), g, saturation);
		g = (g - 0.5) * contrast + 0.5;
		c = mix(c, g, grade);
	}
	if (paper > 0.0) {
		vec2 p = FRAGCOORD.xy;
		float fib = vnoise(p * vec2(0.9, 0.12)) * 0.5 + vnoise(p * 0.35) * 0.5;
		float blot = vnoise(p * 0.004) * 0.6 + vnoise(p * 0.011) * 0.4;
		c *= 1.0 + ((fib - 0.5) * 0.10 + (blot - 0.5) * 0.10) * paper;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
