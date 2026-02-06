extends Spatial

export(Array, Resource) var levels = []
var current_index := 0

func _ready():
	print("🧪 LevelController ready")
	print("🧪 Levels size:", levels.size())

func get_current_level():
	if levels.empty():
		push_error("❌ Levels array is EMPTY")
		return null

	if current_index < 0 or current_index >= levels.size():
		push_error("❌ Level index out of range: " + str(current_index))
		return null

	return levels[current_index]

func apply_level(rocket):
	var level = get_current_level()
	if level == null or rocket == null:
		return

	rocket.level_index = current_index
	#rocket.rocket_type = 1   # Rocket1

	#rocket.level_index = current_index
	#rocket.rocket_type = 2   # Rocket2

	print("🧪 LevelController.apply_level called with index:", current_index)
	print("🧪 Applying LEVEL:", current_index + 1, "for rocket type:", rocket.rocket_type)

	print("✅ Applying LEVEL:", current_index + 1)
	print("   Fuel x", level.fuel_burn_multiplier)
	print("   Wind:", level.wind_force)
	print("   Thrust failure:", level.thrust_failure)
	print("   Overheat:", level.overheat_enabled)

	if rocket.has_method("set_fuel_burn_multiplier"):
		rocket.set_fuel_burn_multiplier(level.fuel_burn_multiplier)

	if rocket.has_method("set_wind_force"):
		rocket.set_wind_force(level.wind_force)

	if rocket.has_method("enable_thrust_failure"):
		rocket.enable_thrust_failure(level.thrust_failure)
		#rocket.engine_failure_enabled = level.engine_failure_enabled
		rocket.enable_thrust_failure(level.thrust_failure) 
		rocket.level = level  # pass reference for heights

	if rocket.has_method("set_overheat"):
		rocket.set_overheat(level.overheat_enabled, level.overheat_rate)

	rocket.wind_switch_heights = level.wind_switch_heights
	rocket.wind_angles = level.wind_angles
