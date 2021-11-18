extends ImageEffect

enum GradientDirection {TOP, BOTTOM, LEFT, RIGHT}

onready var color1 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton
onready var color2 : ColorPickerButton = $VBoxContainer/OptionsContainer/ColorsContainer/ColorPickerButton2
onready var steps : SpinBox = $VBoxContainer/OptionsContainer/StepSpinBox
onready var direction : OptionButton = $VBoxContainer/OptionsContainer/DirectionOptionButton

var levels: int = 0
var srgb_a : Color = Color(0.0, 0.0, 0.0, 1.0)
var srgb_b : Color = Color(1.0, 1.0, 1.0, 1.0)
var point_a : Vector2 = Vector2(0.0, 0.0)
var point_b : Vector2 = Vector2(0.0, 0.0)
var is_srgb : bool = false
var is_lrgb : bool = false
var is_lab : bool = true
var shaderPath : String = "res://src/Shaders/LinearGradient.shader"
var confirmed : bool = false


func _about_to_show() -> void:
	confirmed = false
	var sm : ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(shaderPath)
	preview.set_material(sm)
	._about_to_show()


func _confirmed() -> void:
	confirmed = true
	._confirmed()


func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var selection = _project.bitmap_to_image(_project.selection_bitmap, false)
	var selection_tex = ImageTexture.new()
	selection_tex.create_from_image(selection)

	var affect_selection : bool = selection_checkbox.pressed
	var has_selection : bool = _project.has_selection

	# Depending on how the selection impacts the gradient,
	# may want to adjust vectors based on rect size.
	# var draw_rect: Rect2 = Rect2(Vector2.ZERO, _project.size)
	# if affect_selection and has_selection:
	# draw_rect = _project.get_selection_rectangle()

	# The direction enumeration can be replaced with more flexible
	# spinner boxes origin and destination points if wanted.
	var dir_idx = direction.get_selected_id()
	if dir_idx == GradientDirection.BOTTOM:
		point_a = Vector2(0.0, 1.0)
		point_b = Vector2(0.0, 0.0)
	elif dir_idx == GradientDirection.LEFT:
		point_a = Vector2(0.0, 0.0)
		point_b = Vector2(1.0, 0.0)
	elif dir_idx == GradientDirection.RIGHT:
		point_a = Vector2(1.0, 0.0)
		point_b = Vector2(0.0, 0.0)
	else:
		point_a = Vector2(0.0, 0.0)
		point_b = Vector2(0.0, 1.0)

	if !confirmed:
		preview.material.set_shader_param("srgb_a", srgb_a)
		preview.material.set_shader_param("srgb_b", srgb_b)
		preview.material.set_shader_param("point_a", point_a)
		preview.material.set_shader_param("point_b", point_b)
		preview.material.set_shader_param("levels", levels)
		preview.material.set_shader_param("is_srgb", is_srgb)
		preview.material.set_shader_param("is_lrgb", is_lrgb)
		preview.material.set_shader_param("is_lab", is_lab)
		preview.material.set_shader_param("selection", selection_tex)
		preview.material.set_shader_param("affect_selection", affect_selection)
		preview.material.set_shader_param("has_selection", has_selection)
	else:
		var params = {
			"srgb_a": srgb_a,
			"srgb_b": srgb_b,
			"point_a": point_a,
			"point_b": point_b,
			"levels": levels,
			"is_srgb": is_srgb,
			"is_lrgb": is_lrgb,
			"is_lab": is_lab,
			"selection": selection_tex,
			"affect_selection": affect_selection,
			"has_selection": has_selection
		}
		var gen: ShaderImageEffect = ShaderImageEffect.new()
		gen.generate_image(_cel, shaderPath, params, _project.size)
		yield(gen, "done")


func _ready() -> void:
	color1.get_picker().presets_visible = false
	color2.get_picker().presets_visible = false


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _on_ColorPickerButton_color_changed(_color : Color) -> void:
	srgb_a = _color
	update_preview()


func _on_ColorPickerButton2_color_changed(_color : Color) -> void:
	srgb_b = _color
	update_preview()


func _on_StepSpinBox_value_changed(_value : int) -> void:
	levels = _value
	update_preview()


func _on_DirectionOptionButton_item_selected(_index : int) -> void:
	update_preview()
