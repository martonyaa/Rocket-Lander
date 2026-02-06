extends RigidBody

# =========================
# CONFIG
# =========================
export var lateral_force := 20.0
export var hover_force := 30.0
export var descent_force := 40.0
export var crash_speed := 10.0

export(float) var max_thrust := 1.0
export(float) var thrust := 0.0   # 0..1

export var landing_snap_height := 0.2

export var max_flame_tilt := 6.0   # degrees
export var flame_tilt_speed := 5.0

# FUEL
export var max_fuel := 120.0
export var fuel_burn_rate := 12.0   # fuel per second at full thrust

var fuel := max_fuel
var last_fall_speed := 0.0

var current_flame_tilt := 0.0
var flame_base_rotation := Vector3.ZERO

# The ONLY pad Rocket2 is allowed to land on
var target_pad = null

# =========================
# STATE
# =========================
var landed := false
var exploded := false

# =========================
# NODES
# =========================
onready var landing_sensor = $LandingSensor
onready var thruster_fire = $ThrusterFire
onready var explosion = $Explosion
onready var core_flame = $ThrusterFire_Core
onready var main_scene = get_parent()
onready var landingpad = main_scene.get_node("LandingPad")
onready var landingpad_fire = landingpad.get_node("LandingPadFire")
onready var thruster_sound : AudioStreamPlayer = $ThrusterSound
onready var engine_fail_sound : AudioStreamPlayer = $EngineFailSound
onready var explosion_sound : AudioStreamPlayer = $ExplosionSound
onready var wind_sound : AudioStreamPlayer = $WindSound

# -------------------------
# LEG ANIMATION
# -------------------------
onready var skel_leg1 = $Leg1/Armature001/Skeleton2
onready var skel_leg2 = $Leg2/Armature/Skeleton
onready var skel_leg3 = $Leg3/Armature002/Skeleton3

var bone_leg1 := -1
var bone_leg2 := -1
var bone_leg3 := -1

var rest_leg1 : Transform
var rest_leg2 : Transform
var rest_leg3 : Transform

var legs_deployed := false
var leg_progress := 0.0

export var leg_deploy_speed := 3.0
export var leg_deploy_angle := 180.0  # degrees

const GroundFireScene = preload("res://GroundFire.tscn")

signal fuel_changed(value, max_value)

# 🌬 ALTITUDE-BASED WIND
export var wind_start_height := 200.0   # wind begins affecting rocket
export var wind_full_height := 50.0     # max wind near ground

#var wind_force := 0.0
var wind_strength := 0.0
var wind_vector := Vector3.ZERO

#var wind_meter = null
export var wind_response := 5.0

signal wind_strength_changed(strength)
signal wind_direction_changed(direction)
	  
var wind_switch_heights = []
var wind_angles = []

var _current_wind_index := -1

export var wind_cancel_factor := 3.0

# 🔥 ENGINE FAILURE STATE
var thrust_failure_enabled := false   # set by LevelController
var engine_failed := false
var relight_armed := false
var failure_triggered := false
var triggered_failures := [] 
var level : Level = null
var last_height := 0.0
var engine_fail_sound_played := false

signal engine_failure_text(message)

# 🔧 Engine failure tuning
export var engine_failure_height_scale := 1.0

# 🔥 OVERHEAT STATE
var heat := 0.0
var overheated := false
signal heat_changed(value)
signal overheat_exploded

enum ExplosionReason {
	COLLISION,
	OVERHEAT
}

var explosion_reason = ExplosionReason.COLLISION

var out_of_bounds := false

export var rocket_type := 2     
var level_index := -1          

var explosion_sound_played := false
var wind_sound_playing := false

# 🔊 Wind audio tuning
export var wind_min_db := -40.0   # barely audible
export var wind_max_db := -6.0    # strong wind
export var wind_fade_speed := 4.0 # how fast volume reacts

signal landingpad_ignited
signal fatal_event

var engine_failure_timer : SceneTreeTimer = null

# =========================
# READY
# =========================
func _ready():
	randomize()
	sleeping = false
	can_sleep = false
	mode = RigidBody.MODE_RIGID

	engine_fail_sound.stream.loop = false
	engine_fail_sound_played = false

	engine_fail_sound.connect("finished", self, "_on_engine_fail_finished")

	explosion_sound.stream.loop = false
	explosion_sound_played = false
	
	add_to_group("rocket")

	continuous_cd = true
	contact_monitor = true
	contacts_reported = 8

	flame_base_rotation = thruster_fire.rotation_degrees

	# --- FIND LEG BONES ---
	bone_leg1 = skel_leg1.find_bone("Bone")
	bone_leg2 = skel_leg2.find_bone("Bone")
	bone_leg3 = skel_leg3.find_bone("Bone")

	if bone_leg1 == -1 or bone_leg2 == -1 or bone_leg3 == -1:
		push_error("Rocket4 leg bones not found")
		return

	# --- CACHE REST POSES ---
	rest_leg1 = skel_leg1.get_bone_global_pose(bone_leg1)
	rest_leg2 = skel_leg2.get_bone_global_pose(bone_leg2)
	rest_leg3 = skel_leg3.get_bone_global_pose(bone_leg3)

# =========================
# PHYSICS
# =========================
func _integrate_forces(state):
	if landed or exploded:
		return

	#print("🧪 thrust_failure_enabled =", thrust_failure_enabled)

	var force := Vector3.ZERO
	var t := 0.0

	var current_y = global_transform.origin.y

	# --- HEIGHT-BASED ENGINE FAILURE (descending) ---
	if thrust_failure_enabled and level != null and level.engine_failure_enabled and not landed:
		for h in level.engine_failure_heights:
			# Only trigger when descending past the height
			if last_height > h and current_y <= h and not h in triggered_failures:
				engine_failed = true
				relight_armed = false
				thrust = 0.0
				thruster_fire.emitting = false

				triggered_failures.append(h)

				emit_signal(
				"engine_failure_text",		
				"ENGINE FAILURE — PRESS THRUST TWICE TO RELIGHT"
				)

				# ⏱ keep message for 4 seconds
				if engine_failure_timer:
					engine_failure_timer.disconnect("timeout", self, "_on_engine_failure_timeout")

				engine_failure_timer = get_tree().create_timer(4.0)
				engine_failure_timer.connect("timeout", self, "_on_engine_failure_timeout")

				print("🔥 ENGINE FAILURE triggered at height:", h)
				break

	last_height = current_y

	# Cache downward speed BEFORE physics response
	if linear_velocity.y < 0:
		last_fall_speed = -linear_velocity.y
	else:

		last_fall_speed = 0.0

	# 🌬 ALTITUDE-BASED + DIRECTION-SWITCHING WIND
	if wind_strength > 0.0 and target_pad:

		var height = global_transform.origin.y - target_pad.global_transform.origin.y

		# Strength ramp (same as before)
		t = (wind_start_height - height) / (wind_start_height - wind_full_height)
		t = clamp(t, 0.0, 1.0)

		update_wind_sound(state.step, t)

		# 🔁 WIND DIRECTION SWITCH
		#print("🧪 heights:", wind_switch_heights, " angles:", wind_angles)

		if wind_switch_heights.size() > 0 and wind_angles.size() == wind_switch_heights.size():

			var new_index := -1

			for i in range(wind_switch_heights.size()):
				if height <= wind_switch_heights[i]:
					new_index = i

			# Change direction ONLY when index changes
			if new_index != -1 and new_index != _current_wind_index:
				_current_wind_index = new_index

				var angle = wind_angles[new_index]

				var dir_x := 0.0
				if angle == 0:
					dir_x = 1.0        # RIGHT
				elif angle == 180:
					dir_x = -1.0       # LEFT

				wind_vector = Vector3(dir_x, 0, 0) * wind_strength * wind_response

				print("🌬 WIND SWITCHED")
				print("   Height:", round(height))
				print("   Angle:", wind_angles[new_index])
				print("   Vector:", wind_vector)

		# -----------------------------
		# APPLY WIND FORCE
		# -----------------------------
		state.add_central_force(wind_vector * t)

		emit_signal(
			"wind_strength_changed",
			wind_strength * wind_response * t
		)
		emit_signal("wind_direction_changed", wind_vector)

	# 🔧 RELIGHT SEQUENCE
	if Input.is_action_just_pressed("ui_up") and engine_failed:
	#if InputManager.thrust_pressed and engine_failed:
		if not relight_armed:
			relight_armed = true

			# 🔊 PLAY FAILURE SOUND (ONCE)
			if not engine_fail_sound_played:
				engine_fail_sound_played = true
				engine_fail_sound.stop()
				engine_fail_sound.play()

			print("🔧 RELIGHT ARMED — press again")
		else:
			engine_failed = false
			relight_armed = false

			# 🔥 FORCE THRUST IMMEDIATELY
			thrust = 1.0
			thruster_fire.emitting = true

			emit_signal("engine_failure_text", "")

			print("🔥 ENGINE RELIT")

			# 🚨 VERY IMPORTANT
			# Exit physics step so nothing turns it off this frame
			return

	# 🚀 NORMAL THRUST (only runs if NOT relighting)
	if not engine_failed and fuel > 0.0 and Input.is_action_pressed("ui_up"):
	#if not engine_failed and fuel > 0.0 and InputManager.thrust_pressed:
		thrust = 1.0
		thruster_fire.emitting = true
	else:
		thrust = 0.0
		thruster_fire.emitting = false

	update_flame_tilt(state.step)

	# PAD GUIDANCE
	if target_pad:
		var dir = target_pad.global_transform.origin - global_transform.origin
		var lateral = Vector3(dir.x, 0, dir.z).normalized()
		force += lateral * lateral_force * 0.4

	# LEFT / RIGHT
	var input_x := 0.0
	if Input.is_action_pressed("ui_left"):
	#if InputManager.left_pressed:
		input_x += 1.0
	elif Input.is_action_pressed("ui_right"):
	#elif InputManager.right_pressed:
		input_x -= 1.0

	if input_x != 0.0:
		# effective wind at this height
		var wind_x := wind_vector.x * t

		# cancel part of the wind + apply player force
		force.x += (-wind_x * wind_cancel_factor) + (input_x * lateral_force)

	# HOVER
	if Input.is_action_pressed("ui_up") and fuel > 0.0 and not engine_failed:
	#if not engine_failed and fuel > 0.0 and InputManager.thrust_pressed:
		#print("UI_UP pressed!")
		#print("THRUST ACTIVE")
		var g = ProjectSettings.get_setting("physics/3d/default_gravity")
		force.y += mass * g * gravity_scale + hover_force
		thruster_fire.emitting = true
	else:
		thruster_fire.emitting = false

	# FAST DROP
	if Input.is_action_pressed("ui_down"):
	#if InputManager.descend_pressed:
		force.y -= descent_force

	state.add_central_force(force)
	state.add_central_force(wind_vector)

	# NEVER GO UP
	if fuel > 0.0 and state.linear_velocity.y > 0:
		state.linear_velocity.y = 0

	# PAD LATERAL CORRECTION
	if target_pad and not landed and not exploded:
		var direction = (target_pad.global_transform.origin - global_transform.origin).normalized()
		var lateral_direction = Vector3(direction.x, 0, direction.z)
		force += lateral_direction * lateral_force

		if global_transform.origin.y > target_pad.global_transform.origin.y + 1:
			force.y -= descent_force * 0.5

	update_thruster_sound()

# =========================
# LANDING SENSOR
# =========================
func _on_LandingSensor_body_entered(body):
	print("\n--- LANDING SENSOR HIT ---")
	print("Body:", body.name)
	print("Groups:", body.get_groups())

	var n = body
	while n:
		print(" ↳ parent:", n.name, "groups:", n.get_groups())
		n = n.get_parent()
		var _fuel := max_fuel

	print("--------------------------------")

	if landed or exploded:
		return

	# Ignore self parts (legs, meshes)
	if body.is_in_group("rocket"):
		return

	# 🚫 IGNORE GROUND COMPLETELY
	if body.is_in_group("ground"):
		print("🟡 LandingSensor ignored ground:", body.name)
		return

	var impact_speed := last_fall_speed 

	# Walk up to find what we actually hit
	var node = body
	while node:
		# ✅ LANDING PAD
		if node == target_pad:
			if impact_speed <= crash_speed:
				start_landing()
			else:
				trigger_explosion(global_transform.origin, target_pad)
			return

		# ❌ GROUND / ENVIRONMENT
		if node.is_in_group("ground"):
			trigger_explosion(global_transform.origin, node)
			return

		node = node.get_parent()

# =========================
# LANDING
# =========================
func start_landing():
	if landed:
		return

	print("✅ Rocket4 SAFE LANDING")
	print("Rocket4 landed")

	landed = true
	legs_deployed = true
	exploded = false

	if thruster_sound.playing:
		thruster_sound.stop()

	if engine_fail_sound.playing:
		engine_fail_sound.stop()

	if wind_sound.playing:
		wind_sound.stop()
		wind_sound_playing = false

	# ✅ SAVE PROGRESS (Rocket2)
	if level_index != -1:
		SaveData.mark_completed(level_index, rocket_type)
		print("💾 Level", level_index, "Rocket", rocket_type, "COMPLETED")
		
	#landing_sensor.monitoring = false
	landing_sensor.set_deferred("monitoring", false)
	_disable_all_collisions(self)

	# Stop forces
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	thruster_fire.emitting = false

	# 🚨 EXIT PHYSICS SOLVER COMPLETELY
	yield(get_tree().create_timer(0.15), "timeout")

	thruster_fire.emitting = false
	core_flame.emitting = false

	mode = RigidBody.MODE_KINEMATIC
	sleeping = true
	snap_to_pad()

	#delay_pause_menu_for_main_scene()
	#request_pause_menu_with_message("ROCKET LANDED SUCCESSFULLY!", true)

	get_parent().request_pause_menu_with_message(
			"ROCKET LANDED SUCCESSFULLY!",
			false
		)

	#Save progress
	if level_index != -1:
		SaveData.mark_completed(level_index, rocket_type)

	get_parent().update_pause_button_text()

func _disable_all_collisions(node):
	if node is CollisionShape:
		node.disabled = true
	for child in node.get_children():
		_disable_all_collisions(child)

func snap_to_pad():
	var pad_y = target_pad.global_transform.origin.y

	# distance from rocket origin to feet
	var feet_global_y = $FeetReference.global_transform.origin.y
	var offset = global_transform.origin.y - feet_global_y

	var new_pos = global_transform.origin
	new_pos.y = pad_y + offset + 0.01  # tiny lift

	global_transform.origin = new_pos

# =========================
# EXPLOSION
# =========================
func trigger_explosion(pos = null, collider=null):
	print("\n================ EXPLOSION DEBUG ================")
	print("🚀 Rocket:", name)
	print("📍 Position:", global_transform.origin)
	print("📉 last_fall_speed:", last_fall_speed)
	print("📉 linear_velocity:", linear_velocity)

	if collider:
		print("💥 Collider:", collider.name)
		print("   Type:", collider.get_class())
		print("   Groups:", collider.get_groups())
	else:
		print("💥 Collider: NULL")

	print("🧠 CALL STACK:")
	print_stack()

	print("=================================================\n")

	print("🔥 trigger_explosion called on rocket:", name)
	if exploded:
		return

	exploded = true
	print("💥 Rocket2 EXPLODED")

	# 🔊 PLAY EXPLOSION SOUND (ONCE)
	if not explosion_sound_played:
		explosion_sound_played = true
		explosion_sound.stop()
		explosion_sound.play()

	# 👻 IMMEDIATELY hide rocket visuals
	$Cone003.visible = false
	$Leg1.visible = false
	$Leg2.visible = false
	$Leg3.visible = false

	# 🚨 FORCE SHUT DOWN ALL THRUST + VISUALS (ROCKET4)
	thrust = 0.0

	if thruster_fire:
		thruster_fire.emitting = false

	if core_flame:
		core_flame.emitting = false

	thruster_fire.emitting = false

	if thruster_sound.playing:
		thruster_sound.stop()

	if engine_fail_sound.playing:
		engine_fail_sound.stop()

	if wind_sound.playing:
		wind_sound.stop()
		wind_sound_playing = false

	# Use rocket position if no pos is provided
	if pos == null:
		pos = global_transform.origin

	# 💥 Explosion = visual only
	explosion.global_transform.origin = pos
	explosion.restart()
	explosion.emitting = true

	if explosion_reason == ExplosionReason.OVERHEAT:
		emit_signal("overheat_exploded")
		#request_pause_menu_with_message("GAME OVER — OVERHEAT EXPLOSION!")

		get_parent().request_pause_menu_with_message(
			"GAME OVER — OVERHEAT EXPLOSION!",
			false
		)

		# Mid-air / heat explosion → NO FIRE
		pass
	else:
		# Collision-based explosion
		if collider and collider == target_pad:
			ignite_landing_pad()
			emit_signal("landingpad_ignited") 
			#request_pause_menu_with_message("GAME OVER — LANDING EXPLOSION!")

			get_parent().request_pause_menu_with_message(
				"GAME OVER — LANDING EXPLOSION!",
				false
			)

		else:
			spawn_ground_fire(pos)
			emit_signal("fatal_event") 
			#request_pause_menu_with_message("GAME OVER — CRASH EXPLOSION!")

			get_parent().request_pause_menu_with_message(
			"GAME OVER — CRASH EXPLOSION!",
			false
		)

	mode = RigidBody.MODE_STATIC
	sleeping = true

	# 👻 HIDE EVERYTHING (INCLUDING LEGS)
	yield(get_tree().create_timer(1.0), "timeout")
	hide_entire_rocket()

func hide_entire_rocket():
	visible = false
	set_process(false)
	set_physics_process(false)

func set_target_pad(pad):
	target_pad = pad

func _process(delta):
	update_legs(delta)

	# 🔥 OVERHEAT SYSTEM (LEVEL CONTROLLED)
	if level != null and level.overheat_enabled and not landed and not exploded:
		if Input.is_action_pressed("ui_up") and not engine_failed:
		#if InputManager.thrust_pressed and not engine_failed:
			heat += level.overheat_rate * delta
		else:
			heat -= level.cooldown_rate * delta

		heat = clamp(heat, 0.0, level.max_heat)

		#emit_signal("heat_changed", heat)
		emit_signal("heat_changed", heat, Input.is_action_pressed("ui_up"))

		# 🔥 OVERHEAT EXPLOSION
		#if current_heat >= max_heat:
		if heat >= level.max_heat and not overheated:
			explosion_reason = ExplosionReason.OVERHEAT
			emit_signal("overheat_exploded")
			trigger_explosion(global_transform.origin)
			return

func update_legs(delta):
	if not legs_deployed:
		return

	leg_progress = lerp(leg_progress, 1.0, delta * leg_deploy_speed)

	var rot = Basis(Vector3(1, 0, 0), deg2rad(leg_deploy_angle * leg_progress))

	# LEG 1
	skel_leg1.set_bone_global_pose_override(
		bone_leg1,
		Transform(rot * rest_leg1.basis, rest_leg1.origin),
		1.0,
		true
	)

	# LEG 2
	skel_leg2.set_bone_global_pose_override(
		bone_leg2,
		Transform(rot * rest_leg2.basis, rest_leg2.origin),
		1.0,
		true
	)

	# LEG 3
	skel_leg3.set_bone_global_pose_override(
		bone_leg3,
		Transform(rot * rest_leg3.basis, rest_leg3.origin),
		1.0,
		true
	)

func ignite_landing_pad():
	if not landingpad_fire:
		return

	print("🔥 Landing pad ignited")

	landingpad_fire.emitting = true

func update_flame_tilt(delta):
	var input_dir := 0.0
	if Input.is_action_pressed("ui_left"):
		input_dir = 1.0
	elif Input.is_action_pressed("ui_right"):
		input_dir = -1.0

	# 🔥 FUEL CONSUMPTION
	if thrust > 0.0 and fuel > 0.0:
		fuel -= fuel_burn_rate * thrust * delta
		fuel = max(fuel, 0.0)

	# ⛔ OUT OF FUEL
	if fuel <= 0.0:
		thrust = 0.0

	# 🔔 Emit signal so UI updates
	emit_signal("fuel_changed", fuel, max_fuel)

	# Non-linear response
	input_dir = sign(input_dir) * pow(abs(input_dir), 1.6)

	var target_tilt = input_dir * max_flame_tilt

	# 🔥 Scale by sideways speed instead of thrust
	var speed_factor := clamp(abs(linear_velocity.x) / 6.0, 0.0, 1.0)
	target_tilt *= speed_factor

	current_flame_tilt = lerp(
		current_flame_tilt,
		target_tilt,
		delta * flame_tilt_speed
	)

	thruster_fire.rotation_degrees = flame_base_rotation
	thruster_fire.rotation_degrees.z += current_flame_tilt

func _on_GroundKillZone_body_entered(_body):
	# 🚫 GroundKillZone should NOT handle landing logic
	# Explosion decisions belong to LandingSensor ONLY
	return

func spawn_ground_fire(pos: Vector3):
	var fire = GroundFireScene.instance()
	get_parent().add_child(fire)
	fire.global_transform.origin = pos
	fire.ignite()

func set_wind_force(strength: float):
	# Store max wind strength from level
	wind_strength = strength

	# Base wind direction (+X for now)
	wind_vector = Vector3(1, 0, 0) * wind_strength * wind_response

	print("🌬 Wind strength:", wind_strength)
	print("🌬 Wind vector:", wind_vector)

func enable_thrust_failure(enabled: bool) -> void:
	thrust_failure_enabled = enabled
	print("🧪 Thrust failure enabled:", thrust_failure_enabled)

func update_thruster_sound():
	if exploded or landed or engine_failed or fuel <= 0.0:
		if thruster_sound.playing:
			thruster_sound.stop()
		return

	if thrust > 0.02 and Input.is_action_pressed("ui_up"):
		if not thruster_sound.playing:
			thruster_sound.pitch_scale = lerp(0.9, 1.1, thrust)
			thruster_sound.play()
	else:
		if thruster_sound.playing:
			thruster_sound.stop()

func _on_engine_fail_finished():
	engine_fail_sound.stop()

func update_wind_sound(delta, t):
	# 🔒 Skip wind if rocket is thrusting
	if Input.is_action_pressed("ui_up") or exploded or landed or wind_strength <= 0.0:
		if wind_sound_playing:
			# Fade out quickly
			wind_sound.volume_db = lerp(
				wind_sound.volume_db,
				-80.0,
				delta * wind_fade_speed
			)

			if wind_sound.volume_db <= -70:
				wind_sound.stop()
				wind_sound_playing = false
		return

	# Start wind sound once
	if not wind_sound_playing:
		wind_sound_playing = true
		wind_sound.volume_db = -80
		wind_sound.play()

	# Target volume based on wind ramp (t)
	var target_db = lerp(wind_min_db, wind_max_db, t)

	# Smooth volume change
	wind_sound.volume_db = lerp(
		wind_sound.volume_db,
		target_db,
		delta * wind_fade_speed
	)

func _on_engine_failure_timeout():
	emit_signal("engine_failure_text", "")
	#engine_failure_timer = null
	if engine_failure_timer:
		engine_failure_timer = null