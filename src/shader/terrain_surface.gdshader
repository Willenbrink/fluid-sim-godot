shader_type spatial;

uniform vec4 color;
uniform float heightscale;
uniform sampler2D heightmap;
uniform sampler2D texturemap;

vec3 calc_normal(vec2 uv) {
    const vec3 off = vec3(-1,0,1);
    vec2 texelSize = 1.0 / vec2(textureSize(heightmap, 0));

    float left = texture(heightmap, uv + texelSize * off.xy).y * heightscale;
    float right = texture(heightmap, uv + texelSize * off.zy).y * heightscale;
    float top = texture(heightmap, uv + texelSize * off.yx).y * heightscale;
    float down = texture(heightmap, uv + texelSize * off.yz).y * heightscale;

    return normalize(vec3(left-right, 2.0, down-top));
}

void vertex() {
	vec4 height = texture(heightmap, UV);
    VERTEX.y += height.y * heightscale;
    NORMAL = calc_normal(UV);
}

void fragment() {
	RIM = 0.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	ALBEDO = texture(texturemap, UV * 10.0).xyz;
}
