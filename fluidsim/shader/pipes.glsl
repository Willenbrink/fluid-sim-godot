#[compute]
#version 450
// layout(local_size_x = 8, local_size_y = 8) in;

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
    ivec2 size = imageSize(map_in);
    if(cell_idx.x < 0)
        return imageLoad(map_in, cell_idx + ivec2(1,0)).x;
    if(cell_idx.y < 0)
        return imageLoad(map_in, cell_idx + ivec2(0,1)).x;
    if(cell_idx.x >= size.x)
        return imageLoad(map_in, cell_idx - ivec2(1,0)).x;
    if(cell_idx.y >= size.y)
        return imageLoad(map_in, cell_idx - ivec2(0,1)).x;
    return imageLoad(map_in, cell_idx).x;
}

vec4 flux(ivec2 cell_idx) {
    ivec2 size = imageSize(flux_in);
    if(cell_idx.x < 0)
        return imageLoad(flux_in, cell_idx + ivec2(1,0));
    if(cell_idx.y < 0)
        return imageLoad(flux_in, cell_idx + ivec2(0,1));
    if(cell_idx.x >= size.x)
        return imageLoad(flux_in, cell_idx - ivec2(1,0));
    if(cell_idx.y >= size.y)
        return imageLoad(flux_in, cell_idx - ivec2(0,1));
    return imageLoad(flux_in, cell_idx);
}

float calc_height(ivec2 pos) {
    ivec2 dir = ivec2(1, 0);

    float flux_incoming =
          flux(pos - dir).g
        + flux(pos + dir).r
        + flux(pos - dir.yx).a
        + flux(pos + dir.yx).b;
    float flux_outgoing = flux(pos).r + flux(pos).g + flux(pos).b + flux(pos).a;
    return height(pos) + dt * (flux_incoming - flux_outgoing) / (length * length);
}

void main() {
  ivec2 gidx = ivec2(gl_GlobalInvocationID.xy);
  float height_new = calc_height(gidx);
  imageStore(map_out, gidx, vec4(height_new, 0.0, 0.0, 1.0));
  // imageStore(map_out, gidx, vec4(0.0, 1.0, 0.0, 1.0));
}
