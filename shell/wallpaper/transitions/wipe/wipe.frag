#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float feather;
    float direction;
};

layout(binding = 1) uniform sampler2D fromTexture;
layout(binding = 2) uniform sampler2D toTexture;

// Computes wipe mix: 0 = old, 1 = new
float wipeMask(vec2 uv, float p, float f, float dir) {
    // Hard cut when feather is essentially zero
    if (f < 0.0006) {
        if (dir < 0.5) {
            // new on left, old on right
            return uv.x < p ? 1.0 : 0.0;
        } else if (dir < 1.5) {
            // new on right
            float t = 1.0 - p;
            return uv.x > t ? 1.0 : 0.0;
        } else if (dir < 2.5) {
            // new on top
            return uv.y < p ? 1.0 : 0.0;
        } else {
            // new on bottom
            float t = 1.0 - p;
            return uv.y > t ? 1.0 : 0.0;
        }
    }

    if (dir < 0.5) {
        // left -> right
        return 1.0 - smoothstep(p - f, p + f, uv.x);
    } else if (dir < 1.5) {
        // right -> left
        float t = 1.0 - p;
        return smoothstep(t - f, t + f, uv.x);
    } else if (dir < 2.5) {
        // top -> bottom
        return 1.0 - smoothstep(p - f, p + f, uv.y);
    } else {
        // bottom -> top
        float t = 1.0 - p;
        return smoothstep(t - f, t + f, uv.y);
    }
}

void main() {
    vec2 uv = qt_TexCoord0;

    float p = clamp(progress, 0.0, 1.0);
    float f = clamp(feather, 0.0, 0.5);

    float m = wipeMask(uv, p, f, direction);

    // Force exact endpoints so host handoff is pixel-perfect
    if (p <= 0.0) m = 0.0;
    else if (p >= 1.0) m = 1.0;

    m = clamp(m, 0.0, 1.0);

    vec3 colOld = texture(fromTexture, uv).rgb;
    vec3 colNew = texture(toTexture, uv).rgb;

    vec3 outRgb = mix(colOld, colNew, m);

    fragColor = vec4(outRgb, 1.0) * qt_Opacity;
}
