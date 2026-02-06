extends RigidBody

func safe_get_node(owner, path: String, label := ""):
	if owner == null:
		push_error("❌ NIL OWNER when accessing: " + path + " " + label)
		print_stack()
		return null

	if not owner.has_node(path):
		push_error("❌ NODE NOT FOUND: " + path + " " + label)
		print_stack()
		return null

	return owner.get_node(path)

export var lateral_force := 20.0
export var hover_extra := 30.0
export var descent_force := 40.0

export(float) var max_thrust := 1.0
export(float) var thrust := 0.0   # 0..1

export var max_flame_tilt := 12.0   # degrees
export var flame_tilt_speed := 8.0

export var crash_speed := 6.0
var exploded := false

export(NodePath) var target_pad_path
var target_pad = null

# FUEL
export var max_fuel := 100.0
export var fuel_burn_rate := 12.0   # fuel per second at full thrust

var fuel := max_fuel

var arm_bone_l := -1
var arm_bone_r := -1

var landed := false

var landing_fx_timer = null

#var arm_pad : Node = null
var skeleton_l : Skeleton
var skeleton_r : Skeleton

var arm_pad : Node = null
onready var armpad_fire : Particles = null

onready var thruster = $ThrusterFire
onready var particles_mat = thruster.process_material

onready var landing_smoke = $LandingSmoke
onready var core_flame = $ThrusterFire_Core

onready var explosion = $Explosion
onready var thruster_sound : AudioStreamPlayer3D = $ThrusterSound
onready var engine_fail_sound : AudioStreamPlayer = $EngineFailSound
onready var explosion_sound : AudioStreamPlayer = $ExplosionSound
onready var smoke_sound : AudioStreamPlayer = $SmokeSound
onready var wind_sound : AudioStreamPlayer = $WindSound

#onready var main_scene = get_parent()
#onready var armpad = main_scene.get_node("ArmPad")

#onready var armpad_fire = armpad.get_node("ArmpadFire")

var current_flame_tilt := 0.0
var flame_base_rotation := Vector3.ZERO

var arm_progress := 0.0
export var arm_angle := 18.0
export var arm_speed := 4.0
var arms_deployed := false

var rest_pose_l : Transform
var rest_pose_r : Transform
var rest_cached := false

var bend_arm := false
var bend_amount := 0.0
export var max_bend_angle := 35.0  # degrees
export var bend_speed := 6.0

signal fuel_changed(value, max_value)

const GroundFireScene = preload("res://GroundFire.tscn")

var last_fall_speed := 0.0

var safe_landing := false

export var arm_height_offset := 2.4  # height of arms above armpad origin
var arm_height_y := 0.0
var lateral_locked := false

# 🌬 ALTITUDE-BASED WIND
export var wind_start_height := 200.0   # wind begins affecting rocket
export var wind_full_height := 50.0     # max wind near ground

#var wind_force := 0.0
var wind_strength := 0.0
var wind_vector := Vector3.ZERO

signal wind_strength_changed(strength)
signal wind_direction_changed(direction)

var wind_switch_heights = []
var wind_angles = []

var _current_wind_index := -1

export var wind_cancel_factor := 0.8

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

export var rocket_type := 1     # Rocket1 = 1
var level_index := -1           # set by LevelController

signal fatal_event(reason)
signal armpad_ignited

var thruster_active := false
var explosion_sound_played := false
var smoke_sound_playing := false
var wind_sound_playing := false

# 🔊 Wind audio tuning
export var wind_min_db := -40.0   # barely audible
export var wind_max_db := -6.0    # strong wind
export var wind_fade_speed := 4.0 # how fast volume reacts

var engine_failure_timer : SceneTreeTimer = null

# Landing sensor callback
func _on_LandingSensor_body_entered(body):
	print("\n🧪 [LandingSensor]")
	print("  ↳ Body:", body.name)
	print("  ↳ Groups:", body.get_groups())
	print("  ↳ last_fall_speed:", last_fall_speed)
	print("  ↳ exploded:", exploded, " landed:", landed)

	# ONLY accept ArmPad
	if not body.is_in_group("landing_pad"):
		print("❌ Not ArmPad – rejected")
		return

	print("✅ Rocket1 landed on ArmPad")
	arms_deployed = true
	landed = true
	start_landing_fx()

	# ✅ SAVE PROGRESS
	if level_index != -1:
		SaveData.mark_completed(level_index, rocket_type)
		print("💾 Level", level_index, "Rocket", rocket_type, "COMPLETED")
		
func _ready():
	sleeping = false
	can_sleep = false
	flame_base_rotation = thruster.rotation_degrees

	engine_fail_sound.stream.loop = false
	engine_fail_sound_played = false

	engine_fail_sound.connect("finished", self, "_on_engine_fail_finished")

	explosion_sound.stream.loop = false
	explosion_sound_played = false

	add_to_group("rocket")

	if arm_pad == null:
		var pads = get_tree().get_nodes_in_group("landing_pad")
		if pads.size() > 0:
			arm_pad = pads[0]  # take the first one
		else:
			push_error("❌ No ArmPad found in group 'landing_pad'")
			return  # abort if missing

	set_arm_pad(arm_pad)

	#arm_height_y = armpad.global_transform.origin.y + arm_height_offset
	if arm_pad:
		arm_height_y = arm_pad.global_transform.origin.y + arm_height_offset

func _integrate_forces(state):
	var force = Vector3.ZERO
	var t := 0.0

	var current_y = global_transform.origin.y

	# --- HEIGHT-BASED ENGINE FAILURE (descending) ---
	if thrust_failure_enabled and level != null and level.engine_failure_enabled and not landed:
		for h in level.engine_failure_heights:
			var scaled_h = h * engine_failure_height_scale

			if last_height > scaled_h and current_y <= scaled_h and not h in triggered_failures:
				engine_failed = true
				relight_armed = false
				thrust = 0.0
				thruster.emitting = false

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

	# 🔒 Lock lateral control once below arms
	if not lateral_locked and global_transform.origin.y <= arm_height_y:
		lateral_locked = true
		print("🔒 Lateral movement locked (below arms)")

	# 🌬 ALTITUDE-BASED + DIRECTION-SWITCHING WIND
	if wind_strength > 0.0 and target_pad:

		var height = global_transform.origin.y - target_pad.global_transform.origin.y

		# Strength ramp (same as before)
		t = (wind_start_height - height) / (wind_start_height - wind_full_height)
		t = clamp(t, 0.0, 1.0)

		update_wind_sound(state.step, t)

		# 🔁 WIND DIRECTION SWITCH
		# -----------------------------
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

				wind_vector = Vector3(dir_x, 0, 0) * wind_strength

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
			wind_strength * t
		)
		emit_signal("wind_direction_changed", wind_vector)

	update_flame(state.step)
	update_flame_tilt(state.step)

	var input_x := 0.0
	if Input.is_action_pressed("ui_left"):
		input_x += 1.0
	elif Input.is_action_pressed("ui_right"):
		input_x -= 1.0

	if input_x != 0.0:
		# effective wind at this height
		var wind_x := wind_vector.x * t

		# cancel part of the wind + apply player force
		force.x += (-wind_x * wind_cancel_factor) + (input_x * lateral_force)

	# 🔧 RELIGHT SEQUENCE
	if Input.is_action_just_pressed("ui_up") and engine_failed:
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
			heat = 0.0
			overheated = false
			engine_fail_sound_played = false

			# 🔥 FORCE THRUST IMMEDIATELY
			thrust = 1.0
			thruster.emitting = true

			emit_signal("engine_failure_text", "")

			print("🔥 ENGINE RELIT")

			# 🚨 VERY IMPORTANT
			# Exit physics step so nothing turns it off this frame
			return

	# 🚀 NORMAL THRUST (only runs if NOT relighting)
	if not engine_failed and fuel > 0.0 and Input.is_action_pressed("ui_up"):
		thrust = 1.0
		thruster.emitting = true
	else:
		thrust = 0.0
		thruster.emitting = false

	# 🚀 HOVER / THRUST PHYSICS
	if Input.is_action_pressed("ui_up") and fuel > 0.0 and not engine_failed and not landed:
		var g = ProjectSettings.get_setting("physics/3d/default_gravity")

		# Always fight gravity a bit
		force.y += mass * g * gravity_scale * 0.2

		# Extra lift ONLY if falling fast
		if state.linear_velocity.y < -2.0:
			force.y += hover_extra

	# FAST DESCENT
	if Input.is_action_pressed("ui_down"):
		force.y -= descent_force

	state.add_central_force(force)
	state.add_central_force(wind_vector)

	# NEVER GO UP
	if state.linear_velocity.y > 0:
		state.linear_velocity.y = 0

	if arms_deployed and linear_velocity.y <= 0:
	# Stop applying hover/thrust
		force = Vector3.ZERO

	if landed:
		# Kill all motion
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO

		# Lock sideways movement permanently
		axis_lock_linear_x = true
		axis_lock_linear_z = true
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		axis_lock_angular_z = true

	if exploded:
		return

	# Force explosion if below arms and touching something not ArmPad
	for i in range(state.get_contact_count()):
		var _collider = state.get_contact_collider_object(i)
	
		# If rocket below arms and hitting anything not ArmPad → explode
		if linear_velocity.y <= 0 and not _collider.is_in_group("landing_pad"):
			trigger_explosion(global_transform.origin, _collider)
			break

		# Normal crash-speed-based explosion
		if last_fall_speed > crash_speed:
			trigger_explosion(global_transform.origin, _collider)
			break

	update_thruster_sound()

func set_arm_pad(pad):
	print("🧪 set_arm_pad called with:", pad)
	arm_pad = pad

	if arm_pad:
		armpad_fire = arm_pad.get_node("ArmpadFire")

	skeleton_l = arm_pad.get_node("Arm_L/Armature/Skeleton")
	skeleton_r = arm_pad.get_node("Arm_R/Armature001/Skeleton2")

	# --- FIND BONES ---
	arm_bone_l = skeleton_l.find_bone("Bone")
	arm_bone_r = skeleton_r.find_bone("Bone")

	if arm_bone_l == -1 or arm_bone_r == -1:
		push_error("Arm bones not found")
		return

	# --- CACHE REST POSES ---
	rest_pose_l = skeleton_l.get_bone_global_pose(arm_bone_l)
	rest_pose_r = skeleton_r.get_bone_global_pose(arm_bone_r)
	rest_cached = true

func update_flame(delta):
	# Increase thrust when hovering
	if Input.is_action_pressed("ui_up"):
		thrust += delta * 2.0
	else:
		thrust -= delta * 3.0

	thrust = clamp(thrust, 0.0, 1.0)

	# 🔥 FUEL CONSUMPTION
	if thrust > 0.0 and fuel > 0.0:
		fuel -= fuel_burn_rate * thrust * delta
		fuel = max(fuel, 0.0)

	# ⛔ OUT OF FUEL
	if fuel <= 0.0:
		thrust = 0.0

	# 🔔 Emit signal so UI updates
	emit_signal("fuel_changed", fuel, max_fuel)

	# Animate flame length (Cone height)
	var cone = thruster.get_draw_pass_mesh(0)
	var min_height = 0.15
	var max_height = 2.5
	cone.height = lerp(min_height, max_height, thrust)

	# Animate flame energy
	var min_vel = 2.0
	var max_vel = 12.0
	particles_mat.initial_velocity = lerp(min_vel, max_vel, thrust)

	# Emit only when thrusting
	thruster.emitting = thrust > 0.02

func update_flame_tilt(delta):
	var target_tilt := 0.0

	if Input.is_action_pressed("ui_right"):
		target_tilt = max_flame_tilt      # flame tilts RIGHT
	elif Input.is_action_pressed("ui_left"):
		target_tilt = -max_flame_tilt     # flame tilts LEFT

	current_flame_tilt = lerp(current_flame_tilt, target_tilt, delta * flame_tilt_speed)

	# Apply tilt RELATIVE to base rotation
	thruster.rotation_degrees = flame_base_rotation
	thruster.rotation_degrees.z += current_flame_tilt

func update_arms(delta):
	if not rest_cached:
		return

	# 💥 AFTER EXPLOSION → ONLY BEND RIGHT ARM
	if bend_arm:
		bend_amount = lerp(bend_amount, 5.0, delta * bend_speed)

		var bend_rot = Basis(
			Vector3(0, 1, 0),
			deg2rad(-max_bend_angle * bend_amount)
		)

		skeleton_r.set_bone_global_pose_override(
			arm_bone_r,
			Transform(bend_rot * rest_pose_r.basis, rest_pose_r.origin),
			1.0,
			true
		)

		return  # ⬅️ CRITICAL: stop normal animation
	
	# NORMAL ARM DEPLOYMENT (no explosion)
	if not arms_deployed:
		return

	arm_progress = lerp(arm_progress, 1.0, delta * arm_speed)
	var rot = Basis(Vector3(1, 0, 0), deg2rad(arm_angle * arm_progress))

	# LEFT ARM
	skeleton_l.set_bone_global_pose_override(
		arm_bone_l,
		Transform(rot * rest_pose_l.basis, rest_pose_l.origin),
		1.0,
		true
	)

	# RIGHT ARM (normal deployment)
	skeleton_r.set_bone_global_pose_override(
		arm_bone_r,
		Transform(rot.inverse() * rest_pose_r.basis, rest_pose_r.origin),
		1.0,
		true
	)

func _process(delta):
	update_arms(delta)

	# 🔥 OVERHEAT SYSTEM (LEVEL CONTROLLED)
	if level != null and level.overheat_enabled and not landed and not exploded:
		if Input.is_action_pressed("ui_up") and not engine_failed:
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

func start_landing_fx():
	mode = RigidBody.MODE_STATIC 
	thrust = 0.0
	core_flame.emitting = false
	thruster.emitting = false

	if thruster_sound.playing:
		thruster_sound.stop()

	if engine_fail_sound.playing:
		engine_fail_sound.stop()

	if wind_sound.playing:
		wind_sound.stop()
		wind_sound_playing = false

	# Save the timer reference
	landing_fx_timer = get_tree().create_timer(0.3)
	yield(landing_fx_timer, "timeout")
	
	# Only emit smoke if we haven’t exploded
	if not exploded:
		landing_smoke.emitting = true
		
		# 🔊 PLAY SMOKE SOUND (ONCE)
		if not smoke_sound_playing:
			smoke_sound_playing = true
			smoke_sound.stop()
			smoke_sound.play()

		get_parent().request_pause_menu_with_message(
			"ROCKET LANDED SUCCESSFULLY!",
			false
		)

	#Save progress
	if level_index != -1:
		SaveData.mark_completed(level_index, rocket_type)

	get_parent().update_pause_button_text()

func trigger_explosion(pos = null, collider=null):
	print("\n🔥 [trigger_explosion CALLED]")
	print("  ↳ collider:", collider if collider else "NONE")
	print("  ↳ collider groups:", collider.get_groups() if collider else [])
	print("  ↳ last_fall_speed:", last_fall_speed)
	print("\n🔥 [trigger_explosion]")
	print("  arm_pad:", arm_pad)
	print("  parent:", get_parent())
	print("  collider:", collider)

	if exploded or not visible:
		return
	if exploded:
		return
	exploded = true
	print("💥 EXPLOSION!")

	# 🔊 PLAY EXPLOSION SOUND (ONCE)
	if not explosion_sound_played:
		explosion_sound_played = true
		explosion_sound.stop()
		explosion_sound.play()

	# 🚨 FORCE SHUT DOWN ALL THRUST VISUALS
	thrust = 0.0
	thruster.emitting = false
	core_flame.emitting = false

	if thruster_sound.playing:
		thruster_sound.stop()

	if engine_fail_sound.playing:
		engine_fail_sound.stop()

	if smoke_sound.playing:
		smoke_sound.stop()
		smoke_sound_playing = false

	if wind_sound.playing:
		wind_sound.stop()
		wind_sound_playing = false

	# Stop landing effects
	landing_smoke.emitting = false
	if landing_fx_timer:
		landing_fx_timer.stop()
		landing_fx_timer = null
	core_flame.emitting = false

	# Only detach/bend arms if we hit the ArmPad
	if collider and collider.is_in_group("landing_pad"):
	#if collider and collider.is_in_group("landing_pad") and arm_pad != null:
		detach_arm()
		bend_arm = true
	#else:
	#	print("⚠️ Skipping arm detachment: arm_pad is null")

	# Explosion FX
	explosion.visible = true
	explosion.restart()

	# Decide fire type
	if explosion_reason == ExplosionReason.OVERHEAT:
		emit_signal("overheat_exploded")

		get_parent().request_pause_menu_with_message(
			"GAME OVER — OVERHEAT EXPLOSION!",
			false
		)

		# ❌ NO ground fire for overheat
		print("🔥 Overheat explosion — no ground fire")

	elif collider and collider.is_in_group("landing_pad"):
		if armpad_fire:
			armpad_fire.emitting = true
			emit_signal("armpad_ignited") 
			#request_pause_menu_with_message("GAME OVER — ARMPAD EXPLOSION!")

			get_parent().request_pause_menu_with_message(
				"GAME OVER — ARMPAD EXPLOSION!",
				false
			)

	else:
		spawn_ground_fire(pos)
		emit_signal("fatal_event") 
		#delay_pause_menu_for_main_scene()
		#request_pause_menu_with_message("GAME OVER — CRASH EXPLOSION!")

		get_parent().request_pause_menu_with_message(
			"GAME OVER — CRASH EXPLOSION!",
			false
		)

	# Kill rocket
	sleeping = true
	mode = RigidBody.MODE_STATIC
	$Cylinder.visible = false
	$Armature.visible = false

func detach_arm():
	var arm = arm_pad.get_node("Arm_L") 

	print("🧪 detach_arm called, arm_pad =", arm_pad)

	if arm:
		# Remove from armpad
		arm.get_parent().remove_child(arm)
		get_parent().add_child(arm)
		arm.global_transform = arm_pad.global_transform

		# Make it a RigidBody if it's StaticBody/MeshInstance
		if arm is StaticBody or arm is MeshInstance:
			var new_rigid = RigidBody.new()
			arm.get_parent().remove_child(arm)
			new_rigid.add_child(arm)
			arm.transform = Transform.IDENTITY
			get_parent().add_child(new_rigid)
			new_rigid.global_transform = arm.global_transform

			# → APPLY CUSTOM IMPULSE
			# Example: send toward camera
			var cam = get_viewport().get_camera()
			var dir = (cam.global_transform.origin - new_rigid.global_transform.origin).normalized()
			dir.y = 0.3 # slight upward to make it fly a bit
			new_rigid.apply_impulse(Vector3.ZERO, dir * 15) # tweak strength

func ignite_armpad_base():
	if not core_flame:
		return

	# Duplicate existing particle
	var fire = core_flame.duplicate()
	arm_pad.add_child(fire)

	# Position at base of armpad
	fire.translation = Vector3(0.86, -4.673, 0)  # adjust as needed
	fire.emitting = true

	# Stop it after 20 seconds
	var timer = get_tree().create_timer(20.0)
	timer.connect("timeout", self, "_on_fire_timer_timeout", [fire])

func _on_fire_timer_timeout(fire):
	if fire:
		fire.queue_free()

func set_target_pad(pad):
	target_pad = pad

func spawn_ground_fire(pos: Vector3):
	var fire = GroundFireScene.instance()
	get_parent().add_child(fire)
	fire.global_transform.origin = pos
	fire.ignite()

func set_wind_force(strength: float):
	# Store max wind strength from level
	wind_strength = strength

	# Base wind direction (+X for now)
	wind_vector = Vector3(1, 0, 0) * wind_strength

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