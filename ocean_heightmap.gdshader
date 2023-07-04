shader_type spatial;

uniform float dist_vertices = 0.125;
uniform float amplitude = 1.0;
uniform float frequency = 1.0;
uniform vec2 direction = vec2(1.0,0.3);

float hash(vec2 p) {
  return fract(sin(dot(p * 17.17, vec2(14.91, 67.31))) * 4791.9511);
}

float noise(vec2 x) {
  vec2 p = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  vec2 a = vec2(1.0, 0.0);
  return mix(mix(hash(p + a.yy), hash(p + a.xy), f.x),
         mix(hash(p + a.yx), hash(p + a.xx), f.x), f.y);
}

float fbm(vec2 x) {
  float height = 0.0;
  float amp = amplitude;
  float freq = frequency;
  for (int i = 0; i < 7; i++){
    height += noise(x * freq) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return height;
}

void vertex() {
	vec2 pos_noise = VERTEX.xz + direction * TIME;
	float height = fbm(pos_noise);
	VERTEX.y += height;
	//COLOR.xyz = vec3(height / amplitude);
	COLOR.xyz = vec3((height - 0.5) / amplitude / 4.0,(height - 0.25) / amplitude / 4.0,1.0);
	
	vec2 e = vec2(dist_vertices / 4096000.0, 0.0);
	vec3 normal = normalize(vec3(
		fbm(pos_noise - e) - fbm(pos_noise + e),
		2.0 * e.x,
		fbm(pos_noise - e.yx) - fbm(pos_noise + e.yx)
		));
	NORMAL = normal;
}

void fragment() {
	//COLOR.xyz = vec3(1.0,0.0,0.0);
 	ALBEDO = COLOR.xyz;
}
