shader_type canvas_item;
// Снег, сырость и лужи на земле. Рисует движок: картинка снега (snow_ground) ложится пятнами
// по шуму, лужи отражают небо. Один прямоугольник поверх земли, никакого рисования кодом.

uniform sampler2D snow_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D mask_tex : repeat_enable, filter_linear;
uniform sampler2D ground_tex : filter_linear;
uniform vec2 area_size = vec2(816.0, 609.0);
uniform float tile_px = 420.0;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 puddles[8];
uniform int puddle_count = 0;
uniform vec3 snow_night = vec3(0.58, 0.68, 0.98);
uniform vec3 sky_day = vec3(0.42, 0.47, 0.52);
uniform vec3 sky_night = vec3(0.1, 0.15, 0.27);
uniform vec3 wet_tone = vec3(0.07, 0.09, 0.12);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 pos = UV * area_size;

	// Снег: пятна по шуму. Чем больше cover, тем ниже порог; от 0.8 земля закрыта почти целиком.
	float field = texture(mask_tex, pos / 420.0).r * 0.85 + texture(mask_tex, pos / 110.0 + 0.37).r * 0.15;
	field = (field - 0.5) * 1.5 + 0.5;
	float thr = 1.0 - cover * 1.3;
	float a_snow = smoothstep(thr - 0.2, thr + 0.03, field) * smoothstep(0.0, 0.06, cover);
	// рельеф земли просвечивает: утоптанные тропы и камни темнее, трава светлее
	vec3 g = texture(ground_tex, UV).rgb;
	float lum = dot(g, vec3(0.3, 0.59, 0.11));
	a_snow *= 1.0 - 0.3 * (1.0 - smoothstep(0.1, 0.34, lum));
	vec3 snow = texture(snow_tex, pos / tile_px).rgb;
	snow *= 0.8 + 0.3 * smoothstep(0.08, 0.5, lum);
	float rim = a_snow * (1.0 - a_snow) * 4.0;
	snow *= 1.0 - 0.16 * rim;
	// блеск ледяной крупы: редкие точки мерцают, ночью заметнее
	float cell = hash21(floor(pos / 3.0));
	float glint = step(0.992, cell) * (0.5 + 0.5 * sin(TIME * 2.6 + cell * 90.0));
	snow += vec3(0.6, 0.7, 0.8) * glint * (0.25 + 0.75 * night) * a_snow;
	snow *= mix(vec3(1.0), snow_night, night);

	// Сырость: тёмный налёт пятнами.
	float patchy = texture(mask_tex, pos / 150.0 + 0.61).r;
	float wet_a = wet * (0.05 + 0.12 * patchy);
	vec3 wet_col = wet_tone * mix(1.0, 0.45, night);

	// Лужи: эллипс с рваным краем, внутри отражение неба. Круги от капель рисуют частицы.
	vec3 sky = mix(sky_day, sky_night, night);
	float pa = 0.0;
	float puddle_k = smoothstep(0.12, 0.55, wet);
	for (int i = 0; i < 8; i++) {
		if (i >= puddle_count) {
			break;
		}
		vec3 p = puddles[i];
		vec2 q = (pos - p.xy) / vec2(p.z, p.z * 0.36);
		float wob = (texture(mask_tex, pos / 55.0 + float(i) * 0.17).r - 0.5) * 0.45;
		float r = length(q) + wob;
		pa = max(pa, smoothstep(1.0, 0.62, r));
	}
	pa *= puddle_k;
	// рябь поверхности: медленно ползущий шум, свет отражения чуть гуляет
	float shim = texture(mask_tex, pos / 23.0 + vec2(TIME * 0.02, -TIME * 0.015)).r - 0.5;

	// лужа: тёмная копия земли под ней и лёгкий блик неба, булыжник просвечивает
	vec3 puddle_col = mix(g * 0.55, sky * (1.0 + shim * 0.5), 0.28);
	vec3 base = mix(wet_col, puddle_col, pa);
	float base_a = max(wet_a, pa * 0.5);
	base_a *= 1.0 - a_snow;

	float out_a = max(base_a, a_snow * 0.97);
	vec3 col = mix(base, snow, a_snow);
	COLOR = vec4(col, out_a);
}
