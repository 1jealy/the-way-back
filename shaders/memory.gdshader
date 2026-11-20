shader_type canvas_item;
// 기억 장면(동그라미 1~4): 단색 선 스케치를 배경 위에 희미하게 겹친다.
// 그림의 선(어두운 부분·불투명한 부분)만 ink 색으로 칠하고, 바탕 종이는 빛처럼 아주 옅게 깐다.
// 선이 아주 조금 일렁여서 기억이 떠 있는 느낌을 준다. 담당: B(연출).

uniform float fade : hint_range(0.0, 1.0) = 0.0;     // 0 = 안 보임, 1 = 가장 진할 때
uniform float strength : hint_range(0.0, 1.0) = 0.85; // 가장 진할 때 선의 불투명도
uniform vec4 ink : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.18; // 그림 둘레에 깔리는 옅은 빛
uniform float wobble = 0.0015;

void fragment() {
	vec2 uv = UV + vec2(sin(TIME * 0.9 + UV.y * 9.0), cos(TIME * 0.7 + UV.x * 7.0)) * wobble;
	vec4 tex = texture(TEXTURE, uv);
	// 선 = 불투명하고 어두운 곳(진짜 그림이 흰 바탕이어도 선만 남는다)
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float line = tex.a * (1.0 - smoothstep(0.55, 0.92, lum));
	// 가장자리로 갈수록 흐리게(둥근 비네트)
	vec2 c = (UV - 0.5) * vec2(1.0, 1.25);
	float vign = 1.0 - smoothstep(0.32, 0.62, length(c));
	float a_line = line * strength;
	float a_glow = glow_strength * vign;
	float a = a_line + a_glow * (1.0 - a_line);
	vec3 col = mix(glow.rgb, ink.rgb, a_line / max(a, 0.001));
	COLOR = vec4(col, a * vign * fade);
}
