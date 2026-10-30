extends Resource
## Shared persisted gameplay framing; save-file camera fields never override this view.
@export var yaw_degrees := 45.0
@export var pitch_degrees := -55.0
@export_range(8.0,24.0,0.5) var orthographic_size := 14.0
@export_range(8.0,30.0,0.5) var follow_distance := 14.0
@export_range(1.0,32.0,0.5) var follow_rate := 16.0
@export_range(0.1,2.0,0.01) var wall_aperture_radius := 0.7
@export_range(0.01,0.5,0.01) var wall_aperture_feather := 0.12
@export_range(0.0,1.0,0.01) var wall_minimum_opacity := 0.18
@export var wall_fading_enabled := true
