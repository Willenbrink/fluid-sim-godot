#[compute]
#version 450
// layout(local_size_x = 8, local_size_y = 8) in;

// R - Heightmap - Water
// G - Heightmap - Terrain
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

vec4 map_cell(ivec2 cell_idx) {
    // ivec2 size = imageSize(map_in);
    return imageLoad(map_in, cell_idx);
}

vec4 flux(ivec2 cell_idx) {
    return imageLoad(flux_in, cell_idx);
}

float calc_height(ivec2 pos) {
    // Different directions. Right, Down, Down-left, Down-right
    ivec2 d_r = ivec2(1, 0);
    ivec2 d_d = ivec2(0, 1);
    ivec2 d_dl = ivec2(-1, 1);
    ivec2 d_dr = ivec2(1, 1);

    return flux(pos - d_r).r - flux(pos).r
        + flux(pos - d_d).g - flux(pos).g
        + flux(pos - d_dl).b - flux(pos).b
        + flux(pos - d_dr).a - flux(pos).a;
}

vec4 calc_cell(ivec2 pos) {
    return map_cell(pos) + vec4(calc_height(pos), 0.0, 0.0, 0.0);
}

void main() {
  ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
  vec4 cell_new = calc_cell(gidx);
  imageStore(map_out, gidx, cell_new);
}
