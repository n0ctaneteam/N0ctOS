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

void main()
{
    vec2 uv = qt_TexCoord0;

    float p = clamp(progress, 0.0, 1.0);

    float strength =
        intensity *
        (1.0 - p) *
        (1.0 - p);

    vec2 redOffset =
        vec2(strength, 0.0);

    vec2 blueOffset =
        vec2(-strength, 0.0);

    vec4 oldRed =
        texture(
            fromTexture,
            uv + redOffset
        );

    vec4 oldGreen =
        texture(
            fromTexture,
            uv
        );

    vec4 oldBlue =
        texture(
            fromTexture,
            uv + blueOffset
        );

    vec3 oldRgb =
        vec3(
            oldRed.r,
            oldGreen.g,
            oldBlue.b
        );

    vec3 newRgb =
        texture(
            toTexture,
            uv
        ).rgb;

    float mixAmount =
        smoothstep(
            0.0,
            1.0,
            p
        );

    vec3 rgb =
        mix(
            oldRgb,
            newRgb,
            mixAmount
        );

    float scanline =
        sin(
            uv.y *
            1400.0
        ) *
        0.015 *
        (1.0 - mixAmount);

    rgb += scanline;

    fragColor =
        vec4(
            rgb,
            1.0
        ) *
        qt_Opacity;
}