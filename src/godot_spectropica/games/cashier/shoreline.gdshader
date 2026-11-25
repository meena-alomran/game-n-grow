shader_type spatial;
render_mode unshaded;

uniform float speed;
uniform float period;
uniform sampler2D noise_tex;
uniform float noise_strength;
uniform vec2 noise_scale;
uniform vec2 noise_speed;

void fragment() {
	float v = sin(UV.x * period + (TIME * speed));
	v *= (1.0 - UV.x);
	
	float noise = texture(noise_tex, UV * noise_scale + (TIME * noise_speed)).r;
	
	v += noise * noise_strength;
	
	if(v < 0.5){
		discard;
	}
}
