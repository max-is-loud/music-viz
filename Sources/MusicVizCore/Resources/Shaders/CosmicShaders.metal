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

struct SimParams {
    float deltaTime;
    float timeScale;
    float audioInfluence;
    float gravityStrength;
    float heatDecay;
    float turbulenceStrength;
    float starIgnitionThreshold;
    float collapseThreshold;
    uint particleCount;
    uint fieldResolution;
};

kernel void decay_fields(
    texture2d<half, access::read_write> density [[texture(0)]],
    texture2d<half, access::read_write> heat [[texture(1)]],
    constant SimParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.fieldResolution || gid.y >= params.fieldResolution) {
        return;
    }

    half4 d = density.read(gid);
    half4 h = heat.read(gid);
    density.write(d * half4(0.992), gid);
    heat.write(h * half4(params.heatDecay), gid);
}
