shader_type spatial;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform vec3 ocean_center = vec3(0.0);

uniform vec3 albedo : source_color = vec3(0.0, 0.32, 0.43);
uniform vec3 albedo2 : source_color = vec3(0.0, 0.47, 0.76);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D wave;
uniform sampler2D wave_bump;
uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;
uniform vec2 wave_direction = vec2(0.5, -0.2);
uniform vec2 wave_direction2 = vec2(-0.5, 0.5);
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.1;
uniform float noise_scale = 20.0;
uniform float height_scale = 2.0;

uniform vec3 color_deep : source_color = vec3(0.11, 0.29, 0.33);
uniform vec3 color_shallow : source_color = vec3(0.0, 0.47, 0.76);
uniform float beers_law = 2.0;
uniform float depth_offset = 1.5;

uniform float edge_scale = 0.3;
uniform float depth_near = 1.0;
uniform float depth_far = 100.0;
uniform vec3 edge_color : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 world_pos;
varying float vertex_distance_clamped;

float fresnel_amount(float amount, vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

float linearize_depth(float depth) {
	depth = 2.0 * depth - 1.0;
	return depth_near * depth_far / (depth_far + depth * (depth_near - depth_far));
}

float waveheight(vec2 offset, int mode) {
	vec2 uv1 = (world_pos.xz + offset) / noise_scale + (TIME * wave_direction) * time_scale;
	vec2 uv2 = (world_pos.xz + offset) / noise_scale + (TIME * wave_direction2) * time_scale;
	float h1 = texture(wave, uv1).r;
	float h2 = texture(wave, uv2).r;
	if (mode == 0) {
		return h1;
	}
	if (mode == 1) {
		return h2;
	}
	return mix(h1, h2, 0.5);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float vertex_distance = clamp(distance(world_pos, ocean_center), 0.0, 85.0);
	vertex_distance_clamped = vertex_distance / 85.0;

	float prev_height_x = waveheight(vec2(-0.3, 0.0), 2);
	float next_height_x = waveheight(vec2(0.3, 0.0), 2);
	float prev_height_y = waveheight(vec2(0.0, -0.3), 2);
	float next_height_y = waveheight(vec2(0.0, 0.3), 2);
	float height_mix = waveheight(vec2(0.0, 0.0), 2);

	VERTEX.y += height_mix * height_scale * (1.0 - vertex_distance_clamped);

	float fraction_x = fract(round(UV.x * 1000.0) / 10.0);
	float fraction_y = fract(round(UV.y * 1000.0) / 10.0);
	if (fraction_x != 0.0 && fract(UV.y) == 0.0) {
		VERTEX.y = ((prev_height_x + next_height_x) * height_scale * (1.0 - vertex_distance_clamped)) / 2.0;
	}
	if (fraction_y != 0.0 && fract(UV.x) == 0.0) {
		VERTEX.y = ((prev_height_y + next_height_y) * height_scale * (1.0 - vertex_distance_clamped)) / 2.0;
	}
}

void fragment() {
	float depth_sample = texture(depth_texture, SCREEN_UV).r;
	float depth = PROJECTION_MATRIX[3][2] / (depth_sample + PROJECTION_MATRIX[2][2]);
	float depth_blend = exp((depth + VERTEX.z + depth_offset) * -beers_law);
	depth_blend = clamp(1.0 - depth_blend, 0.0, 1.0);
	float depth_blend_power = clamp(pow(depth_blend, 2.5), 0.0, 1.0);

	vec3 screen_color = textureLod(screen_texture, SCREEN_UV, depth_blend_power * 2.5).rgb;
	vec3 depth_color = mix(color_shallow.rgb, color_deep.rgb, depth_blend_power);
	vec3 color = mix(screen_color * depth_color, depth_color * 0.25, depth_blend_power * 0.5);

	float z_depth = linearize_depth(texture(depth_texture, SCREEN_UV).x);
	float z_pos = linearize_depth(FRAGCOORD.z);
	float z_dif = z_pos - z_depth;

	vec2 time = (TIME * wave_direction) * time_scale;
	vec2 time2 = (TIME * wave_direction2) * time_scale;

	vec3 normal_blend = mix(
		texture(texture_normal, world_pos.xz / 10.0 + time / 10.0).rgb,
		texture(texture_normal2, world_pos.xz / 10.0 + time2 / 10.0).rgb,
		0.5
	);
	vec3 wave_normal_blend = mix(
		texture(wave_bump, world_pos.xz / noise_scale + time).xyz,
		texture(wave_bump, world_pos.xz / noise_scale + time2).xyz,
		0.3
	);

	float fresnel = fresnel_amount(5.0, NORMAL, VIEW);
	vec3 surface_color = mix(albedo, albedo2, fresnel);
	vec3 depth_color_adj = mix(edge_color, color, step(edge_scale, z_dif));

	ALBEDO = clamp(surface_color + depth_color_adj, vec3(0.0), vec3(1.0));
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = mix(wave_normal_blend, normal_blend, 0.5);
	SPECULAR = wave_normal_blend.r;
}
