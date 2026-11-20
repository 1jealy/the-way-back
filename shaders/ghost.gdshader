shader_type canvas_item;
// 7-6 강 건너 안개 속에 비치는 지나온 장소. 색을 하얗게 바래게 하고 가장자리를 안개처럼 흐린다.
// 담당: B(안개 연출).

uniform float fade : hint_range(0.0, 1.0) = 0.0;   // 0 = 안 보임, 1 = 가장 진할 때
uniform float strength : hint_range(0.0, 1.0) = 0.35; // 가장 진할 때의 불투명도
uniform float wash : hint_range(0.0, 1.0) = 0.7;    // 하얗게 바래는 정도
uniform vec4 mist_color : source_color = vec4(0.97, 0.96, 0.93, 1.0);
// 그림 일부(region)만 그릴 때 그 부분의 UV 범위(x0, y0, x1, y1). 가장자리 안개를 그 부분 기준으로 건다.
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = mix(tex.rgb, mist_color.rgb, wash);
	// 가장자리 안개: 위·옆은 넓게, 아래(물 쪽)는 더 빨리 사라진다
	vec2 uv = (UV - uv_rect.xy) / (uv_rect.zw - uv_rect.xy);
	float edge_x = smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x);
	float edge_y = smoothstep(0.0, 0.2, uv.y) * smoothstep(1.0, 0.55, uv.y);
	COLOR = vec4(col, tex.a * edge_x * edge_y * strength * fade);
}
