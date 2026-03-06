#version 300 es
// ╔═══════════════════════════════════════════════════════╗
// ║           VOID AESTHETIC — Hyprshade Shader           ║
// ╚═══════════════════════════════════════════════════════╝
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float VIBRANCE     = 0.30;
const float CONTRAST     = 1.08;
const float BRIGHTNESS   = 0.00;
const float CYAN_BOOST   = 0.04;
const float VIGNETTE_STR = 0.18;
const float SATURATION   = 1.05;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 applyVibrance(vec3 c, float v) {
    float avg  = (c.r + c.g + c.b) / 3.0;
    float maxC = max(c.r, max(c.g, c.b));
    float sat  = (maxC - avg) * 3.0;
    return mix(vec3(luma(c)), c, 1.0 + v * (1.0 - sat));
}

vec3 sCurve(vec3 c, float contrast) {
    return clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
}

vec3 coolGrade(vec3 c, float s) {
    float lum = luma(c);
    c += vec3(0.0, 0.05, 0.15) * clamp(1.0 - lum * 2.5, 0.0, 1.0) * s;
    c += vec3(-0.02, 0.0, 0.06) * clamp(1.0 - abs(lum - 0.4) * 3.0, 0.0, 1.0) * s;
    return clamp(c, 0.0, 1.0);
}

float vignette(vec2 uv, float s) {
    vec2 d = uv - 0.5;
    return 1.0 - dot(d, d) * s * 3.5;
}

void main() {
    vec4 px = texture(tex, v_texcoord);
    vec3 c  = px.rgb;
    float g = luma(c);
    c = mix(vec3(g), c, SATURATION);
    c = applyVibrance(c, VIBRANCE);
    c = coolGrade(c, CYAN_BOOST);
    c = sCurve(c, CONTRAST);
    c += BRIGHTNESS;
    c *= vignette(v_texcoord, VIGNETTE_STR);
    fragColor = vec4(clamp(c, 0.0, 1.0), px.a);
}
