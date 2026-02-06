extends ProgressBar

var max_strength := 100.0  # maximum wind strength
var displayed_value := 0.0
var lerp_speed := 4.0

var wind_direction := Vector3.ZERO 

onready var wind_label = $WindLabel
onready var wind_arrow = $WindArrow

func _ready():
	wind_arrow.modulate = Color(1, 1, 1, 1)  # ALWAYS white
	wind_arrow.rect_pivot_offset = wind_arrow.rect_size * 0.5

	# 🔑 HARD RESET
	displayed_value = 0.0
	value = 0.0
	max_value = max_strength
	wind_label.text = "0.0 m/s"

func update_color():
	var ratio = value / max_value
	if ratio < 0.4:
		modulate = Color(0.2, 0.9, 1) # calm blue
	elif ratio < 0.7:
		modulate = Color(0.1, 0.6, 1) # stronger
	else:
		modulate = Color(0.8, 0.2, 0.2) # warning

#func set_wind(force: Vector3):
	# Compute wind strength
#	var strength = clamp(force.length(), 0, max_strength)
#	var target_value = (strength / max_strength) * max_value
	
	# Smoothly animate progress
	#displayed_value = lerp(displayed_value, target_value, get_process_delta_time() * lerp_speed)
#	displayed_value = lerp(displayed_value, target_value, lerp_speed * 0.016)
#	self.value = displayed_value
	
	# Update numeric label
#	wind_label.text = str(round_1_decimal(strength)) + " m/s"
	
	# Rotate arrow based on wind direction (XZ plane)
#	if force.length() > 0.1:
#		var angle = atan2(force.x, force.z)
#		wind_arrow.rect_rotation = rad2deg(angle)

func set_wind_strength(strength: float):
	value = strength
	wind_label.text = str(round(strength * 10) / 10.0) + " m/s"
	update_color()

func round_1_decimal(value):
	return round(value * 10) / 10.0

func set_wind_direction(dir: Vector3):
	if dir.length() < 0.01:
		return

	wind_direction = dir.normalized()

	# Rotate arrow (XZ plane)
	var angle = atan2(wind_direction.x, wind_direction.z)
	wind_arrow.rect_rotation = rad2deg(angle)
