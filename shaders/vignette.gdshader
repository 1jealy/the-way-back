shader_type canvas_item;
// 화면 가장자리를 살짝 어둡게(#90). 가운데는 그대로, 모서리로 갈수록 tint로 물든다.

uniform float strength : hint_range(0.0, 1.0) = 0.24;
uniform float start : hint_range(0.0, 1.0) = 0.42;
uniform float end : hint_range(0.0, 1.5) = 0.98;
uniform vec4 tint : source_color = vec4(0.07, 0.05, 0.09, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 1.45;  // 16:9 화면에서 위아래보다 좌우가 덜 어두워지게
	float a = smoothstep(start, end, length(p) * 1.25) * strength;
	COLOR = vec4(tint.rgb, a);
}
