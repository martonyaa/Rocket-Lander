extends Control

onready var description_label := $Panel/Description
onready var icon_column := $Panel/IconColumn

onready var panel := $Panel

onready var next_button := $Panel/NextButton
onready var skip_button := $Panel/SkipButton

onready var ui_root := get_node("../UI_Root")

var current_page := 0

const BASE_SCREEN_HEIGHT := 720.0   # design reference
const BASE_FONT_SIZE := 96          # desktop font size

var tutorial_font := preload("res://Roboto/static/Roboto-Regular.ttf")

var skip_used_once := false

signal tutorial_finished
signal tutorial_skipped

var pages = [
	{
		"items": [
			{
				"icon_path": "res://assets/ui/Up.png",
				"icon_pos": Vector2(200, 80),
				"icon_size": Vector2(150, 150),

				"text": "UP: Apply thrust and hover",
				"text_pos": Vector2(400, 30),
				"text_size": Vector2(500, 500)
			},
			{
				"icon_path": "res://assets/ui/Down.png",
				"icon_pos": Vector2(200, 300),
				"icon_size": Vector2(150, 150),

				"text": "DOWN: Increase descent speed",
				"text_pos": Vector2(400, 250),
				"text_size": Vector2(420, 40)
			},
			{
				"icon_path": "res://assets/ui/Left.png",
				"icon_pos": Vector2(200, 520),
				"icon_size": Vector2(150, 150),

				"text": "LEFT: Tilt thrusters left, Rocket moves right",
				"text_pos": Vector2(400, 470),
				"text_size": Vector2(420, 60)
			},
			{
				"icon_path": "res://assets/ui/Right.png",
				"icon_pos": Vector2(200, 740),
				"icon_size": Vector2(150, 150),

				"text": "RIGHT: Tilt thrusters right, Rocket moves left",
				"text_pos": Vector2(400, 690),
				"text_size": Vector2(420, 60)
			}
		]
	},

	# -------- PAGE 2 --------
	{
		"items": [
			{
				"icon_path": "res://assets/ui/Bars.png",
				"icon_pos": Vector2(200, 80),
				"icon_size": Vector2(200, 30),
				"text": "1st Bar: Fuel meter shows remaining fuel",
				"text_pos": Vector2(400, 30),
				"text_size": Vector2(420, 50)
			},
			{
				"icon_path": "res://assets/ui/Bars.png",
				"icon_pos": Vector2(200, 300),
				"icon_size": Vector2(150, 30),
				"text": "2nd Bar: Wind affects rocket direction",
				"text_pos": Vector2(400, 250),
				"text_size": Vector2(420, 50)
			},
			{
				"icon_path": "res://arrow_up.png",
				"icon_pos": Vector2(200, 520),
				"icon_size": Vector2(150, 90),
				"text": "Shows direction of wind",
				"text_pos": Vector2(400, 470),
				"text_size": Vector2(420, 50)
			},
			{
				"icon_path": "res://assets/ui/Bars.png",
				"icon_pos": Vector2(200, 740),
				"icon_size": Vector2(110, 30),
				"text": "3rd Bar: Heat meter increases with thrust period",
				"text_pos": Vector2(400, 690),
				"text_size": Vector2(420, 50)
			}
		]
	},

	# -------- PAGE 3 --------
{
	"items": [
		{
			"icon_path": "",  # no icon
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "NB:",
			"text_pos": Vector2(200, 30),
			"text_size": Vector2(700, 40)
		},
		{
			"icon_path": "",  # no icon
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "Checkout for low fuel which can cause rocket booster freefall.",
			"text_pos": Vector2(0, 250),
			"text_size": Vector2(700, 40)
		},
		{
			"icon_path": "",
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "Checkout for changing wind direction mid fall.",
			"text_pos": Vector2(0, 470),
			"text_size": Vector2(700, 40)
		},
		{
			"icon_path": "",
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "Checkout for engine failure you will have to double tap up button.",
			"text_pos": Vector2(0, 690),
			"text_size": Vector2(700, 40)
		},
		{
			"icon_path": "",
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "Checkout for overheating which will cause an explosion.",
			"text_pos": Vector2(0, 910),
			"text_size": Vector2(700, 40)
		},
		{
			"icon_path": "",
			"icon_pos": Vector2(0, 0),
			"icon_size": Vector2(0, 0),
			"text": "GOODLUCK",
			"text_pos": Vector2(0, 1130),
			"text_size": Vector2(700, 40)
		}
	]
},

# -------- PAGE 4 : CONTROL SETUP --------
{
	"items": [
		{
			"text": "Drag and resize the control buttons to where they feel comfortable.\n\nHold and drag button to desired position.\n\nTap continously to increase button size and tap once to reduce size.\n\nYou can customize again in pause menu.\n\nPress NEXT when done.",
			"text_pos": Vector2(0, 100),
			"text_size": Vector2(700, 80),
			"icon_path": "",
			"icon_pos": Vector2.ZERO,
			"icon_size": Vector2.ZERO
		}
	]
}

]

func _ready():
	next_button.connect("pressed", self, "_on_NextButton_pressed")
	skip_button.connect("pressed", self, "_on_SkipButton_pressed")
	load_page(current_page)

	#load_page(0)

func load_page(index:int) -> void:
	current_page = index
	var page = pages[index]

	var panel_width = panel.rect_size.x
	var reference_width := 1080.0
	var center_offset_x = (panel_width - reference_width) / 2.0

	# clear old content (icons + labels)
	for child in icon_column.get_children():
		child.queue_free()

	for child in panel.get_children():
		if child is Label and child != description_label:
			child.queue_free()

	for item in page["items"]:
		# ICON (skip if no path)
		if item["icon_path"] != "":
			# ICON (Node2D)
			var icon := Sprite.new()
			icon.texture = load(item["icon_path"])
			#icon.position = item["icon_pos"]

			icon.position = Vector2(
			item["icon_pos"].x + center_offset_x,
			item["icon_pos"].y
			)

			icon.scale = item["icon_size"] / icon.texture.get_size()
			icon_column.add_child(icon)

		# TEXT (Control)
		var label := Label.new()
		label.text = item["text"]
		label.add_font_override("font", make_scaled_font())

		# force absolute positioning
		label.anchor_left = 0
		label.anchor_top = 0
		label.anchor_right = 0
		label.anchor_bottom = 0

		#label.rect_position = item["text_pos"]

		label.rect_position = Vector2(
		item["text_pos"].x + center_offset_x,
		item["text_pos"].y
		)

		label.rect_size = item["text_size"]
		label.autowrap = true

		#add_child(label) # or Panel.add_child(label)
		panel.add_child(label)

	# 🔥 ENABLE / DISABLE EDIT MODE
	var uiroot = get_node("/root/MainScene/UI2/UI_Root")
	#uiroot.set_controls_edit_mode(is_last_page())

	if is_controls_setup_page():
		#uiroot.set_controls_edit_mode(true)
		#uiroot.set_controls_edit_mode(true, UI_Root.EditSource.TUTORIAL)
		ui_root.set_controls_edit_mode(true, 1) # 1 = TUTORIAL
	else:
		uiroot.set_controls_edit_mode(false)

func _on_NextButton_pressed():
	if is_last_page():
		#ui_root.set_controls_edit_mode(false)
		ui_root.set_controls_edit_mode(false, 1)

		ui_root.save_controls_layout()

		emit_signal("tutorial_finished")
		hide()
	else:
		load_page(current_page + 1)

#func _on_SkipButton_pressed():
#	#ui_root.set_controls_edit_mode(false)
#	ui_root.set_controls_edit_mode(false, 1)

#	emit_signal("tutorial_skipped")
#	hide()

func _on_SkipButton_pressed():
	# FIRST SKIP → jump to control setup page
	if not skip_used_once and not is_controls_setup_page():
		skip_used_once = true
		load_page(pages.size() - 1)
		return

	# SECOND SKIP (or already on last page) → exit tutorial
	ui_root.set_controls_edit_mode(false, 1)
	emit_signal("tutorial_skipped")
	hide()

func finish_tutorial():
	# mark tutorial as seen
	SaveData.set_seen_tutorial(0, 0)

	# hide tutorial UI
	hide()

	#finish_editing_buttons ()
	
	# tell MainScene to start the game
	if get_parent().has_method("spawn_active_rocket"):
		get_parent().spawn_active_rocket()

func is_last_page() -> bool:
	return current_page >= pages.size() - 1

func is_controls_setup_page() -> bool:
	return current_page == pages.size() - 1

func make_scaled_font() -> DynamicFont:
	var font := DynamicFont.new()
	font.font_data = tutorial_font

	var scale := OS.get_window_size().y / BASE_SCREEN_HEIGHT
	font.size = int(BASE_FONT_SIZE * scale)

	# clamp so it never gets ridiculous
	font.size = clamp(font.size, 64, 72)

	return font
