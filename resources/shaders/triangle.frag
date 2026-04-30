#version 450

layout(push_constant) uniform PushConstants {
    float angle;
    float offsetX;
    float offsetY;
    float colorR;
    float colorG;
    float colorB;
} pc;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(pc.colorR, pc.colorG, pc.colorB, 1.0);
}
