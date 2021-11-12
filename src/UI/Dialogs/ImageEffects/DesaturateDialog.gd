extends ImageEffect


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
	var sm : ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(shaderPath)
	preview.set_material(sm)
	._about_to_show()
	confirmed = false


func set_nodes() -> void:
	preview = $VBoxContainer/AspectRatioContainer/Preview
	selection_checkbox = $VBoxContainer/OptionsContainer/SelectionCheckBox
	affect_option_button = $VBoxContainer/OptionsContainer/AffectOptionButton


func _confirmed() -> void:
	confirmed = true
	._confirmed()

func commit_action(_cel : Image, _project : Project = Global.current_project) -> void:
	var selection = _project.bitmap_to_image(_project.selection_bitmap, false)
	var selection_tex = ImageTexture.new()
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
