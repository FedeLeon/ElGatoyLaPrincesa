shader_type sky;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void sky() {
	float height = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 color = mix(vec3(0.46, 0.61, 0.55), vec3(0.22, 0.40, 0.54), pow(height, 0.55));
	vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y + 0.45, 0.18) * 2.2;
	float n = noise2(cloud_uv) * 0.55 + noise2(cloud_uv * 2.1 + 17.0) * 0.28 + noise2(cloud_uv * 4.2 - 9.0) * 0.17;
	float cloud = smoothstep(0.55, 0.76, n) * smoothstep(0.04, 0.28, EYEDIR.y);
	color = mix(color, vec3(0.83, 0.84, 0.76), cloud * 0.42);
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.35, 0.74, 0.57));
	float sun_dot = max(dot(EYEDIR, sun_dir), 0.0);
	color += vec3(1.0, 0.77, 0.45) * pow(sun_dot, 64.0) * 0.14;
	color += vec3(1.0, 0.91, 0.73) * smoothstep(0.9994, 0.99985, sun_dot) * 0.95;
	COLOR = color;
}
