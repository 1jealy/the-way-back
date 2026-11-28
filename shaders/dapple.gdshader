shader_type canvas_item;
render_mode blend_add;
// 창빛 자리(벽에 비친 빛)에 나뭇잎 그림자가 일렁이게(#151). 그림은 빛 모양(알파)만 쓴다.

uniform vec3 light_color = vec3(1.0, 0.82, 0.55);
uniform float strength = 0.35;
uniform float speed = 1.0;

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

void fragment() {
	float t = TIME * speed;
	float n = vnoise(world * 0.02 + vec2(t * 0.22, t * 0.06)) * 0.65 + vnoise(world * 0.055 - vec2(t * 0.35, 0.0)) * 0.35;
	float leaf = smoothstep(0.36, 0.64, n);
	float a = texture(TEXTURE, UV).a * strength * mix(0.25, 1.0, leaf);
	COLOR = vec4(light_color * a, a);
}
