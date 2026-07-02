# One More Cap Crown Seam Projection

The app icon crown seam lines are generated as projected hemisphere meridians,
not hand-drawn cubic curves.

Model:

- Crown source geometry is the upper hemisphere of a unit sphere.
- A seam is a meridian at fixed azimuth `phi`.
- `theta` runs from the top button to the lower crown edge.

Source-space meridian:

```text
x = sin(theta) * cos(phi)
y = cos(theta)
z = sin(theta) * sin(phi)
theta in [0, pi / 2]
```

Projection:

```text
pitch = 8 degrees
camera_front_azimuth = 60 degrees
relative_phi = phi - camera_front_azimuth + 90 degrees
u = sin(theta) * cos(relative_phi)
depth = sin(theta) * sin(relative_phi)
v = -y * cos(pitch) + depth * sin(pitch)
```

Icon-space mapping:

```text
screen_x = 520 + 280 * crown_scale_x * u
screen_y = 295 + crown_shift_y + 190 * (v + cos(pitch))
```

Current panel model:

```text
total_panel_count = 6
panel_step = 360 / 6 = 60 degrees
panel_boundary_phase = 30 degrees
all panel boundaries = 30, 90, 150, 210, 270, 330 degrees
```

Those six meridians are the full cap model. Rendering is then filtered by
whether the panel boundary lands on the front-facing half of the crown for the
current camera azimuth:

```text
front_depth = sin(relative_phi)
visible boundary if front_depth >= 0.25
```

With `camera_front_azimuth = 60 degrees`, the 30-degree and 90-degree panel
boundaries are the two primary visible seam lines. The back-side panel
boundaries still exist in the model, but they are not drawn for this camera
angle.

Layering:

- The seam paths are clipped to the crown silhouette.
- The brim layer is rendered above the seam layer.
- Because of that ordering, seam geometry can run to the lower crown edge while
  the foreground brim hides the physically occluded portions.
