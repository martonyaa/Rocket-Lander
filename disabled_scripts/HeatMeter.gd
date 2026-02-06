extends ProgressBar

# ALERT SETTINGS
export var heat_alert_threshold := 70      # start alert when heat ≥ 70
export var alert_volume := 0.5

var alert_playing := false
var alert_enabled := true

onready var alert_sound: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	# Add the alert sound node
	add_child(alert_sound)
	alert_sound.stream = preload("res://assets/Sounds/overheat/Alert on the ship.ogg")  
	alert_sound.volume_db = linear2db(alert_volume)
	#alert_sound.loop = true
	alert_sound.stop()

#func set_heat(value, heating := false, pressing_up):
func set_heat(value: float = 0.0, heating: bool = false, pressing_up: bool = false):
	"""
	value: 0..100
	heating: true if rocket is actively increasing heat (ui_up pressed)
	"""
	self.value = clamp(value, 0, 100)
	self.max_value = 100

	# Only trigger alert if enabled
	if not alert_enabled:
		stop_alert()
		return

	if value >= heat_alert_threshold and heating:
		start_alert()
	else:
		stop_alert()

func start_alert():
	if not alert_playing:
		alert_sound.play()
		alert_playing = true

func stop_alert():
	if alert_playing:
		alert_sound.stop()
		alert_playing = false

# Call this when rocket explodes or lands to mute alert permanently
func mute_alert():
	alert_enabled = false
	stop_alert()

# Re-enable alerts (optional)
func enable_alert():
	alert_enabled = true
