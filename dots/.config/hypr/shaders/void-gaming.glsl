#version 300 es
// ╔═══════════════════════════════════════════════════════╗
// ║           VOID GAMING — Hyprshade Shader              ║
// ╚═══════════════════════════════════════════════════════╝
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float CONTRAST     = 1.15;
const float VIBRANCE     = 0.45;
const float SATURATION   = 1.12;
const float SHARPEN_STR  = 0.55;
const float GAMMA        = 0.92;
const float BLACK_CRUSH  = 0.02;
const float VIGNETTE_STR = 0.10;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 sharpen(vec2 uv, float s) {
    vec2 px = vec2(1.0 / 1920.0, 1.0 / 1080.0);
    vec3 center = texture(tex, uv).rgb;
    vec3 blur = (
        texture(tex, uv + vec2(-px.x, 0.0)).rgb +
        texture(tex, uv + vec2( px.x, 0.0)).rgb +
        texture(tex, uv + vec2(0.0, -px.y)).rgb +
        texture(tex, uv + vec2(0.0,  px.y)).rgb
    ) * 0.25;
    return clamp(center + (center - blur) * s, 0.0, 1.0);
}

vec3 vibrance(vec3 c, float v) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float sat  = maxC - minC;
    return clamp(mix(vec3(luma(c)), c, 1.0 + v * (1.0 - sat * 1.5)), 0.0, 1.0);
}

float vignette(vec2 uv, float s) {
    vec2 d = uv - 0.5;
    return 1.0 - dot(d, d) * s * 3.2;
}

void main() {
    vec3 c = sharpen(v_texcoord, SHARPEN_STR);
    c = max(c - BLACK_CRUSH, 0.0) / (1.0 - BLACK_CRUSH);
    c = pow(clamp(c, 0.001, 1.0), vec3(GAMMA));
    float g = luma(c);
    c = mix(vec3(g), c, SATURATION);
    c = vibrance(c, VIBRANCE);
    c = clamp((c - 0.5) * CONTRAST + 0.5, 0.0, 1.0);
    c *= vignette(v_texcoord, VIGNETTE_STR);
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
