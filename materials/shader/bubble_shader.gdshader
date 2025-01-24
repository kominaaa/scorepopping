shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 fresnel_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float fresnel_sharpness : hint_range(1.0, 6.0) = 6.0;
uniform float base_opacity : hint_range(0.0, 1.0) = 0.01;

void fragment() {
	float fresnel = pow(1.0 - dot(normalize(VIEW), normalize(NORMAL)), fresnel_sharpness);

	ALBEDO.rgb = fresnel_color.rgb * fresnel;
	ALPHA = fresnel * fresnel_color.a + base_opacity;
}