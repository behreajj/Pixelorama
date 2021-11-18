shader_type canvas_item;
render_mode unshaded;

uniform sampler2D selection;
uniform bool affect_selection;
uniform bool has_selection;

uniform vec4 srgb_a;
uniform vec4 srgb_b;

uniform vec2 point_a;
uniform vec2 point_b;

uniform bool is_srgb;
uniform bool is_lrgb;
uniform bool is_lab;

uniform int levels;

float ltosChannel(float x) {
    return (x > 0.0031308) ? (pow(x, 0.41666667) * 1.055 - 0.055) : (x * 12.92);
}

float stolChannel(float x) {
    return (x > 0.04045) ? pow((x + 0.055) * 0.94786733, 2.4) : (x * 0.07739938);
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

float scalarProj(vec2 a, vec2 b) {
    return dot(a, b) / dot(b, b);
}

float quantize(float x, int lv) {
    // Unsigned quantize for values in [0.0, 1.0].
    float lf = float(lv);
    return levels < 2 ? x : max(0.0, (ceil(x * lf) - 1.0) / (lf - 1.0));
}

void fragment() {

    // Find factor from clamped scalar projection.
    float fac = scalarProj(
        UV - point_a,
        point_b - point_a);
    fac = clamp(fac, 0.0, 1.0);
    fac = quantize(fac, levels);

    // Mix alpha.
    float alpha_c = mix(srgb_a.a, srgb_b.a, fac);

    // Mix RGB based on desired method.
    vec3 clr_c;
    if (is_srgb) {
        clr_c = mix(srgb_a.rgb, srgb_b.rgb, fac);
    } else if(is_lrgb) {
        clr_c = linearToStandard(mix(
            standardToLinear(srgb_a.rgb),
            standardToLinear(srgb_b.rgb),
            fac));
    } else {
        // Default to CIE LAB.
        vec3 clr_a = xyzToLab(linearToXyz(standardToLinear(srgb_a.rgb)));
        vec3 clr_b = xyzToLab(linearToXyz(standardToLinear(srgb_b.rgb)));
        clr_c = mix(clr_a, clr_b, fac);
        clr_c = linearToStandard(xyzToLinear(labToXyz(clr_c)));
    }

    // Mask out selection if desired.
    if(affect_selection && has_selection) {
        float alpha_sel = texture(selection, UV).a;
        vec4 original_color = texture(TEXTURE, UV);
        clr_c = mix(original_color.rgb, clr_c, alpha_sel);
        alpha_c = mix(original_color.a, alpha_c, alpha_sel);
    }

    COLOR = vec4(clr_c, alpha_c);
}