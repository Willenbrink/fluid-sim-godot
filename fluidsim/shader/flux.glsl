#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8) in;

// R - Heightmap
// G
// B
// A
layout(set = 0, binding = 0, rgba32f) uniform image2D map_in;
layout(set = 0, binding = 2, rgba32f) uniform image2D map_out;

// R - Flux left
// G - Flux right
// B - Flux top
// A - Flux bottom
layout(set = 0, binding = 1, rgba32f) uniform image2D flux_in;
layout(set = 0, binding = 3, rgba32f) uniform image2D flux_out;

const float length = 10.0;
const float dt = 1.0;

float height(ivec2 cell_idx) {
    return imageLoad(map_in, cell_idx).x;
}

vec4 flux(ivec2 cell_idx) {
    return imageLoad(flux_in, cell_idx);
}

vec4 calc_flux(ivec2 pos) {
    ivec2 dir = ivec2(1, 0);

    // TODO some constant? delta t * cross section * gravity / length
    float c = dt * 1.0 / length;
    float K = min(1, height(pos) * length * length
                  / ( dt * ( flux(pos).r + flux(pos).g + flux(pos).b + flux(pos).a )));
    return K * vec4(
        max(0.0, flux(pos).r + c * (height(pos) - height(pos - dir))),
        max(0.0, flux(pos).g + c * (height(pos) - height(pos + dir))),
        max(0.0, flux(pos).b + c * (height(pos) - height(pos - dir.yx))),
        max(0.0, flux(pos).a + c * (height(pos) - height(pos + dir.yx)))
        );
}

void main() {
  ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
  vec4 flux_new = calc_flux(gidx);
  imageStore(flux_out, gidx, flux_new);
  // imageStore(flux_out, gidx, vec4(0.0,1.0,0.0,1.0));
}
