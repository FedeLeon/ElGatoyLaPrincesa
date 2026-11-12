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
	vec3 color = mix(vec3(0.68, 0.76, 0.72), vec3(0.25, 0.48, 0.62), pow(height, 0.55));
	vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y + 0.45, 0.18) * 2.2;
	float n = noise2(cloud_uv) * 0.55 + noise2(cloud_uv * 2.1 + 17.0) * 0.28 + noise2(cloud_uv * 4.2 - 9.0) * 0.17;
	float cloud = smoothstep(0.48, 0.68, n) * smoothstep(0.02, 0.22, EYEDIR.y);
	color = mix(color, vec3(0.94, 0.91, 0.81), cloud * 0.72);
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.35, 0.74, 0.57));
	float sun_dot = max(dot(EYEDIR, sun_dir), 0.0);
	color += vec3(1.0, 0.75, 0.38) * pow(sun_dot, 64.0) * 0.18;
	color += vec3(1.0, 0.91, 0.70) * smoothstep(0.9994, 0.99985, sun_dot) * 1.3;
	COLOR = color;
}
