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

float height(ivec2 cell_idx) {
    return imageLoad(map_in, cell_idx).x;
}

vec4 flux(ivec2 cell_idx) {
    return imageLoad(flux_in, cell_idx);
}

vec4 calc_flux(ivec2 pos) {
    ivec2 dir = ivec2(1, 0);

    // A value of 1.0 that the whole difference is added to the current flux
    float delay = 0.005;
    vec4 flux_new = flux(pos) + delay * vec4(
        height(pos) - height(pos - dir),
        height(pos) - height(pos + dir),
        height(pos) - height(pos - dir.yx),
        height(pos) - height(pos + dir.yx)
      );

    // We store only the outflow flux
    flux_new.r = max(0.0, flux_new.r);
    flux_new.g = max(0.0, flux_new.g);
    flux_new.b = max(0.0, flux_new.b);
    flux_new.a = max(0.0, flux_new.a);


    // Scale flux to avoid negative height
    flux_new *= min(1.0,
                      abs(height(pos))
                    / ( flux_new.r + flux_new.g + flux_new.b + flux_new.a )
      );

    return flux_new;
}

void main() {
  ivec2 cell_idx = ivec2(gl_GlobalInvocationID.xy);
  vec4 flux_new = calc_flux(cell_idx);
  ivec2 size = imageSize(flux_in);
  if(cell_idx.x == 0)
      flux_new.r = 0.0;
  if(cell_idx.y == 0)
      flux_new.b = 0.0;
  if(cell_idx.x == size.x - 1)
      flux_new.g = 0.0;
  if(cell_idx.y == size.y - 1)
      flux_new.a = 0.0;
  imageStore(flux_out, cell_idx, flux_new);
}
