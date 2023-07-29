# Real-time fluid simulation
This project is a real-time fluid simulation implemented using Compute Shaders and Godot.

## References
The work is primarily based on:
- https://data.exppad.com/public/papers/Fast%20Hydraulic%20Erosion%20Simulation%20and%20Visualization%20on%20GPU.pdf
- https://arxiv.org/pdf/2302.06087.pdf

Note that these papers do not have any dampening. When computing the new flux I multiply the previous velocity by e.g. 0.99 to achieve this effect.
