#version 300 es
// ╔═══════════════════════════════════════════════════════╗
// ║           VOID CINEMA — Hyprshade Shader              ║
// ╚═══════════════════════════════════════════════════════╝
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float VIBRANCE     = 0.55;
const float SATURATION   = 1.08;
const float CONTRAST     = 1.06;
const float WARMTH       = 0.025;
const float COOL_SHADOW  = 0.06;
const float VIGNETTE_STR = 0.28;
const float BLOOM_STR    = 0.06;
const float EYE_CARE     = 0.03;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 vibrance(vec3 c, float v) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float sat  = maxC - minC;
    float g = luma(c);
    return clamp(mix(vec3(g), c, 1.0 + v * (1.0 - sat * 1.5)), 0.0, 1.0);
}

vec3 cinematicGrade(vec3 c, float warm, float cool) {
    float lum = luma(c);
    float hiMask  = clamp((lum - 0.5) * 2.5, 0.0, 1.0);
    float shMask  = clamp(1.0 - lum * 2.2, 0.0, 1.0);
    c.r += warm * hiMask;
    c.g += warm * 0.6 * hiMask;
    c.b += cool * shMask;
    c.g += cool * 0.3 * shMask;
    return clamp(c, 0.0, 1.0);
}

vec3 blurSample(vec2 uv) {
    vec2 px = vec2(1.0 / 1920.0, 1.0 / 1080.0) * 2.5;
    vec3 s = texture(tex, uv).rgb;
    s += texture(tex, uv + vec2( px.x,  px.y)).rgb;
    s += texture(tex, uv + vec2(-px.x,  px.y)).rgb;
    s += texture(tex, uv + vec2( px.x, -px.y)).rgb;
    s += texture(tex, uv + vec2(-px.x, -px.y)).rgb;
    return s / 5.0;
}

float vignette(vec2 uv, float s) {
    vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
    return smoothstep(0.5, 0.0, dot(d, d) * s * 1.2);
}

void main() {
    vec4 px  = texture(tex, v_texcoord);
    vec3 c   = px.rgb;
    vec3 blr = blurSample(v_texcoord);

    float g = luma(c);
    c = mix(vec3(g), c, SATURATION);
    c = vibrance(c, VIBRANCE);
    c = cinematicGrade(c, WARMTH, COOL_SHADOW);
    c = clamp((c - 0.5) * CONTRAST + 0.5, 0.0, 1.0);

    // Sahte bloom
    float bright = clamp(luma(c) - 0.65, 0.0, 1.0) * 2.5;
    c += blr * bright * BLOOM_STR;

    // Göz bakımı (mavi ışık azalt)
    c.b = mix(c.b, c.b * (1.0 - EYE_CARE), 0.5);
    c.r += EYE_CARE * 0.012;

    // Sinematik vignette
    float vig = vignette(v_texcoord, VIGNETTE_STR);
    c = mix(c * 0.15, c, vig);

    fragColor = vec4(clamp(c, 0.0, 1.0), px.a);
}
