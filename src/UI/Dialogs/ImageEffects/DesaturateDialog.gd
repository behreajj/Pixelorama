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

var lab_a: Vector3 = Vector3(0.0, 0.0, 0.0)
var lab_b: Vector3 = Vector3(100.0, 0.0, 0.0)


func _about_to_show():
	# This assumes that a gradient consisting of two polar
	# colors is enough. Maybe a texture look up of an
	# image with 1x1 swatch for each palette entry would be
	# the next step?

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
#		preview.material.set_shader_param("srgb_a", srgb_a)
#		preview.material.set_shader_param("srgb_b", srgb_b)
		preview.material.set_shader_param("lab_a", lab_a)
		preview.material.set_shader_param("lab_b", lab_b)
		preview.material.set_shader_param("lab_a", lab_a)
		preview.material.set_shader_param("alpha_a", srgb_a.a)
		preview.material.set_shader_param("alpha_b", srgb_b.a)
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
#			"srgb_a": srgb_a,
#			"srgb_b": srgb_b,
			"lab_a": lab_a,
			"lab_b": lab_b,
			"alpha_a": srgb_a.a,
			"alpha_b": srgb_b.a,
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
	lab_a = srgb_to_lab(srgb_a)
	update_preview()


func _on_DestColorPicker_color_changed(color: Color) -> void:
	srgb_b = color
	lab_b = srgb_to_lab(srgb_b)
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


func s_to_l_channel(x: float) -> float:
	if x > 0.04045:
		return pow((x + 0.055) * 0.94786733, 2.4)
	else:
		return x * 0.07739938


func standard_to_linear(c: Color) -> Color:
	return Color(
		s_to_l_channel(c.r),
		s_to_l_channel(c.g),
		s_to_l_channel(c.b),
		c.a)


func linear_to_xyz(c: Color) -> Vector3:
	return Vector3(
		0.41241086 * c.r + 0.35758457 * c.g + 0.1804538 * c.b,
		0.21264935 * c.r + 0.71516913 * c.g + 0.07218152 * c.b,
		0.019331759 * c.r + 0.11919486 * c.g + 0.95039004 * c.b)


func xyz_to_lab_channel(x: float) -> float:
	if x > 0.008856:
		return pow(x, 0.3333333)
	else:
		return 7.787 * x + 0.13793103


func xyz_to_lab(xyz:Vector3) -> Vector3:
	var vx: float = xyz_to_lab_channel(xyz.x * 1.0521111)
	var vy: float = xyz_to_lab_channel(xyz.y)
	var vz: float = xyz_to_lab_channel(xyz.z * 0.91841704)

	return Vector3(
		116.0 * vy - 16.0,
		500.0 * (vx - vy),
		200.0 * (vy - vz))


func srgb_to_lab(srgb: Color) -> Vector3:
	return xyz_to_lab(linear_to_xyz(standard_to_linear(srgb)))
