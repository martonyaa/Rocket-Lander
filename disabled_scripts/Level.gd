extends Resource
class_name Level

export(float) var fuel_burn_multiplier := 1.0
export(float) var wind_force := 0.0
export(bool) var thrust_failure := false
export(bool) var overheat_enabled := false   
export(float) var overheat_rate := 15.0      # heat per second
export(float) var cooldown_rate := 20.0      # cooling per second
export(float) var max_heat := 100.0

export(Array, float) var wind_switch_heights = []
export(Array, float) var wind_angles = []

# --- HEIGHT-BASED ENGINE FAILURE ---
export(Array, float) var engine_failure_heights = []
export(bool) var engine_failure_enabled := false