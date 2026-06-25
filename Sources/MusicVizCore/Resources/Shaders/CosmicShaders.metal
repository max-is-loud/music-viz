#include <metal_stdlib>
using namespace metal;

struct SeedParticle {
    float x;
    float y;
    float vx;
    float vy;
    float mass;
    float temperature;
    float age;
    uint kind;
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

vertex VertexOut particle_vertex(
    uint vertexID [[vertex_id]],
    const device SeedParticle *particles [[buffer(0)]]
) {
    SeedParticle p = particles[vertexID];
    float heat = clamp(p.temperature, 0.0, 1.0);
    float kindGlow = clamp(float(p.kind) / 6.0, 0.0, 1.0);

    VertexOut out;
    out.position = float4(p.x, p.y, 0.0, 1.0);
    out.pointSize = clamp(1.5 + p.mass * 1.4 + heat * 4.0, 1.0, 9.0);
    out.color = float4(
        0.25 + heat * 0.75 + kindGlow * 0.15,
        0.35 + heat * 0.45,
        0.65 + (1.0 - heat) * 0.30,
        0.72
    );
    return out;
}

fragment float4 particle_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
