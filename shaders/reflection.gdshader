shader_type canvas_item;
// 물에 비친 모습(5-2 물그림자, scripts/game/water_reflection.gd). 뒤집어 복사한 모습에 씌운다.
// 물결처럼 가로로 일렁이고, 발(물 위 선)에서 멀어질수록 옅어지고 물빛에 묻힌다.
// clarity 1 = 또렷, 0.3 근처 = 흐림(5-2 하윤). 복사한 모습의 자식들도 이 재질을 쓴다(use_parent_material).
// 담당: B(물 반사).

uniform float clarity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 water_tint : source_color = vec4(0.62, 0.72, 0.86, 1.0);
uniform float ripple = 4.0;        // 가로 일렁임 폭(px)
uniform float water_y = 816.0;     // 물 위 선(발이 닿는 높이, 화면 세계 좌표)
uniform float fade_length = 240.0; // 이만큼 내려가면 거의 안 보인다(px)

varying float world_y;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	world_y = w.y;
	// 물결: 높이마다 조금씩 옆으로 밀린다. 흐릴수록 크게.
	VERTEX.x += sin(w.y * 0.08 + TIME * 2.4) * ripple * (1.4 - clarity);
}

void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(water_tint.rgb, c.rgb, 0.3 + clarity * 0.6);
	float depth = clamp((world_y - water_y) / fade_length, 0.0, 1.0);
	c.a *= (0.2 + clarity * 0.65) * (1.0 - depth * (1.0 - clarity * 0.6));
	// 가로 물결 줄무늬로 끊는다(흐릴수록 진하게)
	float band = 0.7 + 0.3 * sin(world_y * 0.6 + TIME * 3.0);
	c.a *= mix(band, 1.0, clarity);
	COLOR = c;
}
