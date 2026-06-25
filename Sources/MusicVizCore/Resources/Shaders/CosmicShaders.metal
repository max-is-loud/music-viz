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

kernel void integrate_particles(
    device SeedParticle *particles [[buffer(0)]],
    constant SimParams &params [[buffer(1)]],
    texture2d<half, access::read_write> density [[texture(0)]],
    texture2d<half, access::read_write> heat [[texture(1)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= params.particleCount) {
        return;
    }

    SeedParticle p = particles[id];
    float2 pos = float2(p.x, p.y);
    float2 uv = clamp(pos * 0.5 + 0.5, 0.0, 0.999);
    uint2 cell = uint2(uv * float(params.fieldResolution));

    half4 oldDensity = density.read(cell);
    half4 oldHeat = heat.read(cell);
    float massDeposit = clamp(p.mass * 0.0008, 0.0, 0.02);
    float heatDeposit = clamp(p.temperature * 0.002, 0.0, 0.03);
    density.write(oldDensity + half4(massDeposit, 0.0, 0.0, 1.0), cell);
    heat.write(oldHeat + half4(heatDeposit, heatDeposit * 0.35, 0.0, 1.0), cell);

    float centerPull = 0.004 * params.gravityStrength;
    float2 acceleration = -pos * centerPull;
    acceleration += float2(
        sin((pos.y + p.age) * 19.0),
        cos((pos.x - p.age) * 17.0)
    ) * params.turbulenceStrength * 0.0004;

    float dt = params.deltaTime * params.timeScale;
    p.vx += acceleration.x * dt;
    p.vy += acceleration.y * dt;
    p.x += p.vx * dt * 60.0;
    p.y += p.vy * dt * 60.0;
    p.age += dt;
    p.temperature = clamp(p.temperature * 0.999 + length(acceleration) * 0.35, 0.0, 3.0);

    if (length(float2(p.x, p.y)) > 1.08) {
        p.x *= -0.86;
        p.y *= -0.86;
        p.vx *= -0.35;
        p.vy *= -0.35;
    }

    particles[id] = p;
}
