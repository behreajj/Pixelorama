extends ImageEffect


enum GreyMethod {
	LUMINANCE = 0,
	AVERAGE = 1,
	HSL = 2,
	HSV = 3
}

var confirmed: bool = false
var is_avg: bool = false
var is_hsl: bool = false
var is_hsv: bool = false

var levels: int = 0

var percent: float = 1.0

var shaderPath: String = "res://src/Shaders/Desaturate.shader"

var srgb_a: Color = Color(0.0, 0.0, 0.0, 1.0)
var srgb_b: Color = Color(1.0, 1.0, 1.0, 1.0)


func _about_to_show():
	# TODO: Implement sRGB->CIE LAB conversion in GDScript in case
	# calculating origin and destination once in CPU is faster than
	# having it done on the GPU?

	var sm : ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(shaderPath)
	preview.set_material(sm)
	._about_to_show()
	confirmed = false


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionWidget/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/SelectionWidget/AffectOptionButton


func _confirmed() -> void:
	confirmed = true
	._confirmed()

func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var selection: Image = _project.bitmap_to_image(_project.selection_bitmap, false)
	var selection_tex: ImageTexture = ImageTexture.new()
	selection_tex.create_from_image(selection)

	if !confirmed:
		preview.material.set_shader_param("is_avg", is_avg)
		preview.material.set_shader_param("is_hsl", is_hsl)
		preview.material.set_shader_param("is_hsv", is_hsv)
		preview.material.set_shader_param("srgb_a", srgb_a)
		preview.material.set_shader_param("srgb_b", srgb_b)
		preview.material.set_shader_param("levels", levels)
		preview.material.set_shader_param("percent", percent)
		preview.material.set_shader_param("selection", selection_tex)
		preview.material.set_shader_param("affect_selection", selection_checkbox.pressed)
		preview.material.set_shader_param("has_selection", _project.has_selection)
	else:
		var params = {
			"is_avg": is_avg,
			"is_hsl": is_hsl,
			"is_hsv": is_hsv,
			"srgb_a": srgb_a,
			"srgb_b": srgb_b,
			"levels": levels,
			"percent": percent,
			"selection": selection_tex,
			"affect_selection": selection_checkbox.pressed,
			"has_selection": _project.has_selection
		}
		var gen: ShaderImageEffect = ShaderImageEffect.new()
		gen.generate_image(_cel, shaderPath, params, _project.size)
		yield(gen, "done")


func _on_OriginColorPicker_color_changed(color: Color) -> void:
	srgb_a = color
	update_preview()


func _on_DestColorPicker_color_changed(color: Color) -> void:
	srgb_b = color
	update_preview()


func _on_LevelsSpinBox_value_changed(value: float) -> void:
	levels = int(value)
	update_preview()


func _on_PercentSpinBox_value_changed(value: float) -> void:
	percent = value * 0.01
	update_preview()


func _on_MethodComboBox_item_selected(index: int) -> void:
	is_avg = index == GreyMethod.AVERAGE
	is_hsl = index == GreyMethod.HSL
	is_hsv = index == GreyMethod.HSV
	update_preview()
