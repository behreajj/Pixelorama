shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform bool affect_selection;
uniform bool has_selection;

uniform bool is_avg;
uniform bool is_hsl;
uniform bool is_hsv;

// uniform vec4 srgb_a;
// uniform vec4 srgb_b;

uniform vec3 lab_a;
uniform float alpha_a;
uniform vec3 lab_b;
uniform float alpha_b;

uniform int levels;
uniform float percent;

float ltosChannel(float x) {
    return (x > 0.0031308) ? (pow(x, 0.41666667) * 1.055 - 0.055) : (x * 12.92);
}

float stolChannel(float x) {
    return (x > 0.04045) ? pow((x + 0.055) * 0.94786733, 2.4) : (x * 0.07739938);
}

float grayAverage(vec3 c) {
    return (c.r + c.g + c.b) * 0.3333333;
}

float grayHsv(vec3 c) {
    return max(c.r, max(c.g, c.b));
}

float grayHsl(vec3 c) {
    return 0.5 * (max(c.r, max(c.g, c.b)) + min(c.r, min(c.g, c.b)));
}

float grayLuminance(vec3 lrgb) {
	return ltosChannel(
		0.21264935 * lrgb.r
		+ 0.71516913 * lrgb.g
		+ 0.07218152 * lrgb.b);
}

vec3 standardToLinear(vec3 c) {
    return vec3(
        stolChannel(c.r),
        stolChannel(c.g),
        stolChannel(c.b));
}

vec3 linearToStandard(vec3 c) {
    return vec3(
        ltosChannel(c.r),
        ltosChannel(c.g),
        ltosChannel(c.b));
}

vec3 linearToXyz(vec3 c) {
    return vec3(
        0.41241086 * c.r + 0.35758457 * c.g + 0.1804538 * c.b,
        0.21264935 * c.r + 0.71516913 * c.g + 0.07218152 * c.b,
        0.019331759 * c.r + 0.11919486 * c.g + 0.95039004 * c.b);
}

vec3 xyzToLinear(vec3 xyz) {
    return vec3(
        3.2408123 * xyz.x - 1.5373085 * xyz.y - 0.49858654 * xyz.z,
        -0.969243 * xyz.x + 1.8759663 * xyz.y + 0.041555032 * xyz.z,
        0.0556384 * xyz.x - 0.20400746 * xyz.y + 1.0571296 * xyz.z);
}

vec3 xyzToLab(vec3 xyz) {
    vec3 v = xyz * vec3(1.0521111, 1.0, 0.91841704);

    v.x = (v.x > 0.008856) ? pow(v.x, 0.3333333) : (7.787 * v.x + 0.13793103);
    v.y = (v.y > 0.008856) ? pow(v.y, 0.3333333) : (7.787 * v.y + 0.13793103);
    v.z = (v.z > 0.008856) ? pow(v.z, 0.3333333) : (7.787 * v.z + 0.13793103);

    return vec3(
        116.0 * v.y - 16.0,
        500.0 * (v.x - v.y),
        200.0 * (v.y - v.z));
}

vec3 labToXyz(vec3 lab) {
    float vy = (lab.x + 16.0) * 0.00862069;
    float vx = lab.y * 0.002 + vy;
    float vz = vy - lab.z * 0.005;

    float vye3 = vy * vy * vy;
    float vxe3 = vx * vx * vx;
    float vze3 = vz * vz * vz;

    vy = (vye3 > 0.008856) ? vye3 : ((vy - 0.13793103) * 0.12841916);
    vx = (vxe3 > 0.008856) ? vxe3 : ((vx - 0.13793103) * 0.12841916);
    vz = (vze3 > 0.008856) ? vze3 : ((vz - 0.13793103) * 0.12841916);

    return vec3(vx * 0.95047, vy, vz * 1.08883);
}

float quantize(float x, int lv) {
    // Unsigned quantize for values in [0.0, 1.0].
    float lf = float(lv);
    return levels < 2 ? x : max(0.0, (ceil(x * lf) - 1.0) / (lf - 1.0));
}

void fragment() {

    // Determine mix factor based on requested type.
    vec4 original_color = texture(TEXTURE, UV);
    vec3 srgb_origin = original_color.rgb;
    vec3 lrgb_origin = standardToLinear(srgb_origin);
    vec3 xyz_origin = linearToXyz(lrgb_origin);
    vec3 lab_origin = xyzToLab(xyz_origin);

    float factor = 0.0;
    if (is_avg) {
        factor = grayAverage(original_color.rgb);
    } else if (is_hsl) {
        factor = grayHsl(original_color.rgb);
    } else if (is_hsv) {
        factor = grayHsv(original_color.rgb);
    } else {
		// factor = grayLuminance(lrgb_origin);
        factor = lab_origin.x * 0.01;
    }

    // For pixel art, discrete steps may be preferable
    // over a smooth transition.
    factor = quantize(min(factor, 1.0), levels);

    // Convert a color to LAB.
    // This could be done on the CPU and passed in.
    // vec3 lrgb_a = standardToLinear(srgb_a.rgb);
    // vec3 xyz_a = linearToXyz(lrgb_a);
    // vec3 lab_a = xyzToLab(xyz_a);

    // Convert b color to LAB.
    // This could be done on the CPU and passed in.
    // vec3 lrgb_b = standardToLinear(srgb_b.rgb);
    // vec3 xyz_b = linearToXyz(lrgb_b);
    // vec3 lab_b = xyzToLab(xyz_b);

    // Mix colors by brightness, then mix by percent.
    // Convert from CIE LAB back to sRGB.
    vec3 lab_c = mix(lab_a, lab_b, factor);
    vec3 lab_d = mix(lab_origin, lab_c, percent);
    vec3 xyz_d = labToXyz(lab_d);
    vec3 lrgb_d = xyzToLinear(xyz_d);
    lrgb_d = min(max(lrgb_d, 0.0), 1.0);
    vec3 srgb_d = linearToStandard(lrgb_d);

    vec3 output;
    if(affect_selection && has_selection) {
        vec4 selection_color = texture(selection, UV);
        output = mix(original_color.rgb, srgb_d, selection_color.a);
    } else {
        output = srgb_d;
    }

    // Decision on what to do about alpha here.
    // Decided to not have it impacted by percent.
    float alpha_c = mix(alpha_a, alpha_b, factor);
    float alpha_d = min(original_color.a, alpha_c);
    COLOR = vec4(output.rgb, alpha_d);
}