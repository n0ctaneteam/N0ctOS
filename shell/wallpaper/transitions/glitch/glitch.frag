#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float intensity;
};

layout(binding = 1) uniform sampler2D fromTexture;
layout(binding = 2) uniform sampler2D toTexture;

float hash(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 splitSample(sampler2D tex, vec2 uv, float off) {
    float r = texture(tex, clamp(uv + vec2(off, 0.0), vec2(0.0), vec2(1.0))).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, clamp(uv - vec2(off, 0.0), vec2(0.0), vec2(1.0))).b;
    return vec3(r, g, b);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(progress, 0.0, 1.0);

    // Bell curve peaking at p=0.5 – strongest glitch in the middle
    float peak = 1.0 - abs(p * 2.0 - 1.0);
    peak = pow(clamp(peak, 0.0, 1.0), 0.72);
    float str = intensity * peak * 6.0;

    // Block / slice offsets
    float slices = 46.0;
    float sid = floor(uv.y * slices + p * 7.3);
    float sRnd = hash(vec2(sid, floor(p * 31.0)));
    float sOff = 0.0;
    if (sRnd > 0.615)
        sOff = (sRnd - 0.5) * str * 0.40;

    float rRnd = hash(vec2(floor(uv.y * 118.0), floor(p * 26.0)));
    float rOff = 0.0;
    if (rRnd > 0.775)
        rOff = (rRnd - 0.5) * str * 0.15;

    vec2 uvOld = clamp(uv + vec2(sOff + rOff, 0.0), vec2(0.0), vec2(1.0));
    vec2 uvNew = clamp(uv + vec2(-sOff * 0.58 - rOff * 0.52, 0.0), vec2(0.0), vec2(1.0));

    float chroma = str * 0.026;

    vec3 colOld = splitSample(fromTexture, uvOld, chroma);
    vec3 colNew = splitSample(toTexture, uvNew, chroma * 0.60);

    // Horizontal scan interference
    float scan = sin(uv.y * 880.0) * 0.014 * str;
    colOld += scan;
    colNew += scan;

    // Film grain
    float gn = (hash(uv * 1.85 + vec2(p * 3.4, p * 5.9)) - 0.5) * str * 0.082;
    colOld += gn;
    colNew += gn;

    float base = smoothstep(0.18, 0.84, p);

    // Digital dissolve driven by noise
    float n = hash(uv * 1.45 + vec2(p * 2.4, p * 1.8));
    float dither = step(n, base + str * 0.17 * (n - 0.5));

    float mixA = mix(base, dither, clamp(str * 0.48, 0.0, 1.0));
    mixA = clamp(mixA, 0.0, 1.0);

    vec3 rgb = mix(colOld, colNew, mixA);

    // Flicker / exposure pops
    if (str > 0.34) {
        float f = hash(vec2(floor(p * 52.0), 1.0));
        if (f > 0.73)
            rgb *= 1.14;
        else if (f < 0.19)
            rgb *= 0.87;

        if (f > 0.935)
            rgb = mix(rgb, vec3(1.0) - rgb * 0.11, 0.34);
    }

    // Single tear band
    float tRnd = hash(vec2(floor(p * 38.0), 0.7));
    if (str > 0.52 && tRnd > 0.56) {
        float ty = fract(tRnd * 1.68 + p * 0.32);
        float d = abs(uv.y - ty);
        if (d < 0.009 * str) {
            float tOff = (tRnd - 0.5) * str * 0.075;
            vec2 tUv = clamp(uv + vec2(tOff, 0.0), vec2(0.0), vec2(1.0));
            vec3 tCol = mix(texture(fromTexture, tUv).rgb,
                            texture(toTexture, tUv).rgb,
                            base);
            rgb = mix(rgb, tCol, 0.56);
        }
    }

    // Clean anchors so final frame is pure new wallpaper
    if (p >= 0.982) {
        vec3 fin = texture(toTexture, uv).rgb;
        rgb = mix(rgb, fin, smoothstep(0.982, 1.0, p));
    }
    if (p <= 0.018) {
        vec3 ini = texture(fromTexture, uv).rgb;
        rgb = mix(ini, rgb, smoothstep(0.0, 0.018, p));
    }

    fragColor = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), 1.0) * qt_Opacity;
}
