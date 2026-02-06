extends ProgressBar

var low_fuel := false
var critical_fuel := false
var blink_time := 0.0

export var blink_speed_low := 6.0     # 10–20%
export var blink_speed_critical := 12.0  # <10%

onready var fuel_alert_sound: AudioStreamPlayer = $FuelAlertSound
var alert_playing := false
var ignore_alert := false   # when true, alert is inaudible

func _ready():
	percent_visible = false

func set_fuel(current, max_fuel):
	max_value = max_fuel
	value = current

	var ratio = current / max_fuel

	if ratio < 0.1:
		low_fuel = true
		critical_fuel = true
		modulate = Color(1, 0.2, 0.2)   # deep red
	elif ratio < 0.2:
		low_fuel = true
		critical_fuel = false
		modulate = Color(1, 0.3, 0.2)   # red
	elif ratio < 0.5:
		low_fuel = false
		critical_fuel = false
		modulate = Color(1, 0.8, 0.2)   # yellow
	else:
		low_fuel = false
		critical_fuel = false
		modulate = Color(0.2, 0.9, 0.3) # green

	# Reset when not blinking
	if not low_fuel:
		blink_time = 0.0
		modulate.a = 1.0

#func _process(delta):
#	if not low_fuel:
#		return

#	var speed = blink_speed_critical if critical_fuel else blink_speed_low
#	blink_time += delta * speed

	# Alpha pulse
#	modulate.a = 0.4 + 0.6 * abs(sin(blink_time))

func _process(delta):
	if not low_fuel or ignore_alert:
		if alert_playing:
			fuel_alert_sound.stop()
			alert_playing = false
		return

	# BLINKING
	var speed = blink_speed_critical if critical_fuel else blink_speed_low
	blink_time += delta * speed
	modulate.a = 0.4 + 0.6 * abs(sin(blink_time))

	# 🔊 FUEL ALERT SOUND
	if critical_fuel:
		if not alert_playing:
			fuel_alert_sound.play()
			alert_playing = true
	else:
		# optional: low fuel alert
		if not fuel_alert_sound.playing:
			fuel_alert_sound.play()

func set_alert_enabled(enabled: bool):
	ignore_alert = not enabled
	if ignore_alert and fuel_alert_sound.playing:
		fuel_alert_sound.stop()
		alert_playing = false

func _on_rocket_event():
	set_alert_enabled(false)  # mute during explosion or landing
