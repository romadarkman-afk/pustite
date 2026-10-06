shader_type canvas_item;
// Атмосфера и дверь в одном материале — переход между ними плавный, без смены шейдера.
// Туман из заранее сгенерированной текстуры шума: в v0.1 4 октавы шума считались
// на каждый пиксель каждый кадр — дорого для Mali/Adreno начального уровня.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float night : hint_range(0.0, 1.0) = 1.0;
uniform float lamp_power : hint_range(0.0, 2.0) = 1.0;
uniform vec2 lamp_pos = vec2(0.5, 0.36);
uniform float aspect = 2.0;
uniform float door_mix : hint_range(0.0, 1.0) = 0.0;
uniform float door_open : hint_range(0.0, 0.5) = 0.05;
uniform float knock : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float n1 = texture(noise_tex, uv * vec2(1.1, 1.1 * aspect) + vec2(TIME * 0.010, TIME * 0.006)).r;
	float n2 = texture(noise_tex, uv * vec2(2.3, 2.3 * aspect) - vec2(TIME * 0.007, TIME * 0.012)).r;
	float fog = n1 * 0.65 + n2 * 0.35;

	vec3 col = mix(vec3(0.129, 0.169, 0.184), vec3(0.039, 0.063, 0.075), night);
	col += (fog - 0.5) * mix(0.08, 0.12, night) * vec3(0.55, 0.72, 0.80);

	vec2 a = vec2(1.0, aspect);
	float d = distance(uv * a, lamp_pos * a);
	float flick = 0.90 + 0.10 * sin(TIME * 7.3) * sin(TIME * 3.1 + 1.7);
	col += exp(-d * 3.4) * lamp_power * flick * vec3(0.86, 0.62, 0.28) * mix(0.22, 0.55, night);

	float x = abs(uv.x - 0.5);
	float crack = smoothstep(door_open, 0.0, x);
	float halo = smoothstep(door_open * 5.0 + 0.02, 0.0, x);
	float dflick = 0.88 + 0.12 * sin(TIME * 9.1) * sin(TIME * 2.7);
	vec3 dcol = vec3(0.035, 0.055, 0.066) + fog * 0.03;
	dcol += (crack * 1.5 + halo * 0.22) * dflick * (1.0 + knock * 0.9) * vec3(0.94, 0.70, 0.34);
	col = mix(col, dcol, door_mix);

	col = mix(col, vec3(0.50, 0.10, 0.08), flash * 0.38);
	col *= 1.0 - smoothstep(0.34, 0.95, distance(uv, vec2(0.5))) * (0.85 + knock * 0.1);
	col += (hash(uv * 997.0 + fract(TIME)) - 0.5) * 0.022;
	COLOR = vec4(col, 1.0);
}
