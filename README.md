# Real-time fluid simulation
This project is a real-time fluid simulation implemented using Compute Shaders and Godot.

## References
The work is primarily based on:
- https://data.exppad.com/public/papers/Fast%20Hydraulic%20Erosion%20Simulation%20and%20Visualization%20on%20GPU.pdf
- https://arxiv.org/pdf/2302.06087.pdf

A nice overview of different methods can be found here, unfortunately not open access:
- https://dl.acm.org/doi/pdf/10.1145/2700533

## Usage
- Load the project and enter the main scene
- Select the Fluidsim object
- Switch to 3D and pan to the desired view. The texture has some post processing for multiple colors and height, the sprite is the raw data
- Check "Run in Editor" on the Fluidsim object

You should now see a cube of water slowly spread out.

## TODO
- Interactivity (i.e. adding/removing liquids)
- Using a terrain instead of using a flat surface
- Physics (e.g. floating)
