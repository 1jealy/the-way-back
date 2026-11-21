shader_type canvas_item;
// 영정사진의 흐린 사진(1-2, 7-8). amount 1 = 누구인지 안 보일 만큼 흐림, 0 = 또렷.
// 액자 테(frame 바깥)는 또렷하게 두고 안쪽 사진만 흐리고 바랜다.
// 웹(Compatibility)에서도 돌게 밉맵 없이 둘레를 여러 번 읽어 섞는다. 담당: B(연출).

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float radius_px = 30.0;     // amount 1일 때 흐림 반지름(그림 픽셀)
uniform float fade_to_paper = 0.6;  // amount 1일 때 바랜 종이색으로 덮는 정도
uniform vec4 paper : source_color = vec4(0.8, 0.79, 0.76, 1.0);
uniform vec4 frame = vec4(0.08, 0.06, 0.92, 0.94); // 사진 안쪽(UV: 왼, 위, 오른, 아래)

// fragment의 COLOR는 이미 그림 색을 곱한 값이라, 꼭짓점 색(modulate)만 따로 받아 둔다.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool inside = UV.x > frame.x && UV.y > frame.y && UV.x < frame.z && UV.y < frame.w;
	if (!inside || amount <= 0.001) {
		COLOR = base * tint;
	} else {
		// TEXTURE_PIXEL_SIZE는 TextureRect(웹·Compatibility)에서 0으로 올 때가 있어 그림 크기를 직접 잰다
		vec2 px = radius_px * amount / vec2(textureSize(TEXTURE, 0));
		vec4 sum = vec4(0.0);
		float wsum = 0.0;
		for (int x = -4; x <= 4; x++) {
			for (int y = -4; y <= 4; y++) {
				vec2 o = vec2(float(x), float(y)) / 4.0;
				float w = exp(-dot(o, o) * 1.2);
				vec2 uv = clamp(UV + o * px, frame.xy, frame.zw);
				sum += texture(TEXTURE, uv) * w;
				wsum += w;
			}
		}
		vec4 c = sum / wsum;
		c.rgb = mix(c.rgb, paper.rgb, fade_to_paper * amount);
		COLOR = c * tint;
	}
}
