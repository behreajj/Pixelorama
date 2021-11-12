shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform bool affect_selection;
uniform bool has_selection;

uniform bool is_avg;
uniform bool is_hsl;
uniform bool is_hsv;

uniform vec4 srgb_a;
uniform vec4 srgb_b;

uniform int levels;
uniform float percent;

float grayAverage(vec3 c) {
    return (c.r + c.g + c.b) / 3.0;
}

float grayHsv(vec3 c) {
    return max(c.r, max(c.g, c.b));
}

float grayHsl(vec3 c) {
    return 0.5 * (max(c.r, max(c.g, c.b)) + min(c.r, min(c.g, c.b)));
}

float stolChannel(float x) {
    return (x > 0.04045) ? pow((x + 0.055) / 1.055, 2.4) : (x / 12.92);
}

vec3 standardToLinear(vec3 c) {
    return vec3(
        stolChannel(c.r),
        stolChannel(c.g),
        stolChannel(c.b));
}

float ltosChannel(float x) {
    return (x > 0.0031308) ? (pow(x, 1.0 / 2.4) * 1.055 - 0.055) : (x * 12.92);
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
    vec3 v = xyz * vec3(1.0 / 0.95047, 1.0, 1.0 / 1.08883);

    v.x = (v.x > 0.008856) ? pow(v.x, 1.0 / 3.0) : (7.787 * v.x + 16.0 / 116.0);
    v.y = (v.y > 0.008856) ? pow(v.y, 1.0 / 3.0) : (7.787 * v.y + 16.0 / 116.0);
    v.z = (v.z > 0.008856) ? pow(v.z, 1.0 / 3.0) : (7.787 * v.z + 16.0 / 116.0);

    return vec3(
        116.0 * v.y - 16.0,
        500.0 * (v.x - v.y),
        200.0 * (v.y - v.z));
}

vec3 labToXyz(vec3 lab) {
    float vy = (lab.x + 16.0) / 116.0;
    float vx = lab.y / 500.0 + vy;
    float vz = vy - lab.z / 200.0;

    float vye3 = vy * vy * vy;
    float vxe3 = vx * vx * vx;
    float vze3 = vz * vz * vz;

    vy = (vye3 > 0.008856) ? vye3 : ((vy - 16.0 / 116.0) / 7.787);
    vx = (vxe3 > 0.008856) ? vxe3 : ((vx - 16.0 / 116.0) / 7.787);
    vz = (vze3 > 0.008856) ? vze3 : ((vz - 16.0 / 116.0) / 7.787);

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
    float factor = 0.0;
    if (is_avg) {
        factor = grayAverage(original_color.rgb);
    } else if (is_hsl) {
        factor = grayHsl(original_color.rgb);
    } else if (is_hsv) {
        factor = grayHsv(original_color.rgb);
    } else {
        // This could be shortened to just the y component
        // of XYZ converted linear to standard, but the
        // CIE LAB conversion methods are available anyway.
        vec3 lrgb_origin = standardToLinear(original_color.rgb);
        vec3 xyz_origin = linearToXyz(lrgb_origin);
        vec3 lab_origin = xyzToLab(xyz_origin);

        // LAB expected range is [0, -110, -110] to [0, 110, 110].
        // There is no true upper bound for a and b, the above
        // are based on lab that falls in sRGB gamut.
        factor = lab_origin.x * 0.01;
    }

    // For pixel art, discrete steps may be preferable
    // over a smooth transition.
       factor = quantize(factor, levels);

    // This assumes that a gradient consisting of two polar
    // colors is enough. Maybe a texture look up of an
    // image with 1x1 swatch for each palette entry would be
    // the next step?

    // Convert a color to LAB.
    // This could be done on the CPU and passed in.
    vec3 lrgb_a = standardToLinear(srgb_a.rgb);
    vec3 xyz_a = linearToXyz(lrgb_a);
    vec3 lab_a = xyzToLab(xyz_a);

    // Convert b color to LAB.
    // This could be done on the CPU and passed in.
    vec3 lrgb_b = standardToLinear(srgb_b.rgb);
    vec3 xyz_b = linearToXyz(lrgb_b);
    vec3 lab_b = xyzToLab(xyz_b);

    // Mix colors by brightness, convert back to sRGB.
    vec3 lab_c = mix(lab_a, lab_b, factor);
    vec3 xyz_c = labToXyz(lab_c);
    vec3 lrgb_c = xyzToLinear(xyz_c);
    vec3 srgb_c = linearToStandard(lrgb_c);

    // Clamp to sRGB gamut.
    // Might want to test to see if this is necessary.
    srgb_c = min(max(srgb_c, 0.0), 1.0);

    // Mix according to percentage.
    srgb_c = mix(original_color.rgb, srgb_c, percent);

    vec3 output;
    if(affect_selection && has_selection) {
        vec4 selection_color = texture(selection, UV);
        output = mix(original_color.rgb, srgb_c, selection_color.a);
    } else {
        output = srgb_c;
    }

    // Final alpha is the minimum of the user selected colors
    // and the source color.
    // Not sure if alpha premultiply is an issue.
    float alpha_c = mix(srgb_a.a, srgb_b.a, factor);
    COLOR = vec4(output.rgb, min(original_color.a, alpha_c));
    COLOR = vec4(output.rgb, original_color.a);
}