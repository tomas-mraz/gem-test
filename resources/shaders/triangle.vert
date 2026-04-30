#version 450

layout(location = 0) in vec3 inPosition;

layout(push_constant) uniform PushConstants {
    float angle;
    float offsetX;
    float offsetY;
    float colorR;
    float colorG;
    float colorB;
} pc;

void main() {
    float c = cos(pc.angle);
    float s = sin(pc.angle);
    mat2 rot = mat2(c, s, -s, c);
    vec2 rotated = rot * inPosition.xy;
    vec2 translated = rotated + vec2(pc.offsetX, pc.offsetY);
    gl_Position = vec4(translated, inPosition.z, 1.0);
}
