//
//  SkyShader.metal
//  UntoldEngine3D
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include <simd/simd.h>

using namespace metal;

// Procedural atmospheric sky background pass. Renders a fullscreen NDC quad and, per pixel,
// reconstructs a world-space view ray from the camera through that pixel, then evaluates an
// atmospheric scattering model along that ray using the engine's active directional light as
// the Sun. See: https://blog.maximeheckel.com/posts/on-rendering-the-sky-sunsets-and-planets/

struct SkyVertexInput {
    float3 position [[ attribute(0) ]];
};

struct SkyVertexOutput {
    float4 position [[position]];
    float3 rayDir;
};

vertex SkyVertexOutput vertexSkyShader(
    SkyVertexInput vert [[stage_in]],
    constant SkyUniforms &skyUniforms [[buffer(skyPassUniformIndex)]]
) {
    SkyVertexOutput out;

    out.position = float4(vert.position.xy, 0.0, 1.0);

    // Unproject the far-plane point under this pixel into world space, then derive the ray
    // direction from the camera position. Any depth value along the same NDC (x,y) column lies
    // on the same view ray, so the choice of z here (1.0) doesn't affect the resulting direction
    // regardless of the active depth (forward/reverse-Z) convention.
    float4 clipFar = float4(vert.position.x, vert.position.y, 1.0, 1.0);
    float4 viewFar = skyUniforms.invProjectionMatrix * clipFar;
    viewFar /= viewFar.w;
    float4 worldFar = skyUniforms.invViewMatrix * viewFar;

    out.rayDir = normalize(worldFar.xyz - skyUniforms.cameraPosition);

    return out;
}

// ---------------------------------------------------------------------------------------------
// Atmospheric scattering model (single-scattering Rayleigh + Mie + ozone raymarch), following
// https://blog.maximeheckel.com/posts/on-rendering-the-sky-sunsets-and-planets/ and the classic
// wwwtyro/glsl-atmosphere reference it builds on. All distances/heights are in kilometers so the
// scattering coefficients below (given "per km") can be used directly without unit conversion.
//
// This is deliberately a brute-force per-pixel raymarch, not the Hillaire LUT pipeline
// (Transmittance/Multi-scatter/Sky-View/Aerial-Perspective) described in the article. It is
// isolated in computeSkyColor() below precisely so it can be swapped for LUT lookups later
// without touching the pass/pipeline wiring.
// ---------------------------------------------------------------------------------------------

constant float kPI = 3.14159265358979323846;

// Planet/atmosphere geometry, in kilometers.
constant float kPlanetRadiusKm = 6371.0;
constant float kAtmosphereRadiusKm = 6471.0; // ~100 km atmosphere shell (Karman line)
constant float kMinCameraHeightKm = 0.0005; // 0.5 m floor, avoids degenerate ray-sphere math at h=0

// Rayleigh scattering (wavelength-dependent molecular scattering), exponential density falloff.
constant float3 kRayleighScattering = float3(0.0058, 0.0135, 0.0331); // per km
constant float kRayleighScaleHeightKm = 8.0;

// Mie scattering (aerosols/haze), exponential density falloff, concentrated near the ground.
// kMieExtinction assumes a single-scattering albedo of ~0.9 (extinction slightly exceeds
// scattering); revisit both when multi-scattering is added.
constant float kMieScattering = 0.003; // per km
constant float kMieExtinction = 0.0033; // per km
constant float kMieScaleHeightKm = 1.2;
constant float kMieAnisotropy = 0.76; // Henyey-Greenstein g

// Ozone absorption: does not scatter light, just removes it. Modeled as a triangular density
// layer (not exponential like Rayleigh/Mie) peaked at kOzoneHeightKm.
constant float3 kOzoneAbsorption = float3(0.00065, 0.00188, 0.00008); // per km
constant float kOzoneHeightKm = 25.0;
constant float kOzoneWidthKm = 15.0;

constant int kPrimarySteps = 16; // samples along the view ray
constant int kLightSteps = 8; // samples along the secondary (sun) ray per primary sample

// Angular radius of the sun disk (real sun is ~0.5 degrees across).
constant float kSunDiskCosAngle = 0.9998;

// Soft corona around the sun disk: a wide, low-frequency angular falloff independent of the crisp
// disk edge above (and independent of any HDR bloom post-process, which is off by default). Lower
// exponent = wider/softer glow; kSunGlowStrength scales its brightness relative to the disk itself.
constant float kSunGlowExponent = 800.0;
constant float kSunGlowStrength = 0.35;

// Cheap multiple-scattering approximation strength (see computeSkyColor). 0 disables it
// (pure single scattering); tuned by eye against a horizon color sweep across sun elevations.
constant float kMultiScatterStrength = 1.4;

// Ground tint (see fragmentSkyShader): darkens the horizon-color approximation used for rays that
// hit the ground, so it reads as a distinct (if undetailed) surface rather than a mirror of the
// sky. 1.0 = same brightness as the horizon itself; lower = darker ground.
constant float kGroundDarkening = 0.6;

// Analytic ray-sphere intersection for a unit-length ray direction. Returns (near, far) distances
// along the ray; near > far means the ray misses the sphere entirely.
static float2 raySphereIntersect(float3 rayOrigin, float3 rayDir, float radius) {
    float b = dot(rayOrigin, rayDir);
    float c = dot(rayOrigin, rayOrigin) - radius * radius;
    float discriminant = b * b - c;
    if (discriminant < 0.0) {
        return float2(1e9, -1e9);
    }
    float sqrtDiscriminant = sqrt(discriminant);
    return float2(-b - sqrtDiscriminant, -b + sqrtDiscriminant);
}

static float rayleighDensity(float heightKm) {
    return exp(-max(heightKm, 0.0) / kRayleighScaleHeightKm);
}

static float mieDensity(float heightKm) {
    return exp(-max(heightKm, 0.0) / kMieScaleHeightKm);
}

static float ozoneDensity(float heightKm) {
    return max(0.0, 1.0 - abs(heightKm - kOzoneHeightKm) / kOzoneWidthKm);
}

static float rayleighPhase(float mu) {
    return 3.0 / (16.0 * kPI) * (1.0 + mu * mu);
}

// Cornette-Shanks approximation of Mie phase (energy-normalized Henyey-Greenstein).
static float miePhase(float mu, float g) {
    float gg = g * g;
    float denom = 1.0 + gg - 2.0 * g * mu;
    return (3.0 / (8.0 * kPI)) * ((1.0 - gg) * (1.0 + mu * mu)) / ((2.0 + gg) * pow(max(denom, 1e-4), 1.5));
}

// Marches from a point in the atmosphere toward the sun, accumulating the optical depth
// (Rayleigh in x, Mie in y, ozone in z) sunlight loses before reaching that point.
static float3 lightMarchOpticalDepth(float3 samplePos, float3 sunDir) {
    float2 hit = raySphereIntersect(samplePos, sunDir, kAtmosphereRadiusKm);
    float stepSize = max(hit.y, 0.0) / float(kLightSteps);

    float3 opticalDepth = float3(0.0);
    float t = 0.0;
    for (int j = 0; j < kLightSteps; j++) {
        float3 samplePosJ = samplePos + sunDir * (t + stepSize * 0.5);
        float heightKm = length(samplePosJ) - kPlanetRadiusKm;

        opticalDepth += float3(rayleighDensity(heightKm), mieDensity(heightKm), ozoneDensity(heightKm)) * stepSize;
        t += stepSize;
    }

    return opticalDepth;
}

// Integrates single-scattered Rayleigh + Mie light along the view ray, attenuated by Beer's law
// using the combined Rayleigh/Mie/ozone extinction, then adds a sun disk attenuated by the same
// transmittance. rayOrigin is in planet-centered space (planet center at the coordinate origin).
// includeSunDisk disables the disk/corona terms; isotropicPhase neutralizes the Rayleigh/Mie phase
// functions' directional peak toward the sun (Mie in particular, with its strongly forward-biased
// g=0.76, produces a bright glare wherever the ray points near the sun even without the disk/glow
// terms at all). Both are used by the ground tint in fragmentSkyShader, which reuses this function
// with a leveled ray direction: without them, that leveled ray would carry a bright streak toward
// the sun's azimuth onto the ground, in addition to the intended flat horizon-color tint.
static float3 computeSkyColor(float3 rayOrigin, float3 rayDir, float3 sunDir, float3 sunColor, float sunIntensity, bool includeSunDisk = true, bool isotropicPhase = false) {
    float2 atmosphereHit = raySphereIntersect(rayOrigin, rayDir, kAtmosphereRadiusKm);
    if (atmosphereHit.x > atmosphereHit.y) {
        return float3(0.0); // ray misses the atmosphere entirely (looking out into space)
    }

    float2 groundHit = raySphereIntersect(rayOrigin, rayDir, kPlanetRadiusKm);
    float rayStart = max(atmosphereHit.x, 0.0);
    float rayEnd = groundHit.x > 0.0 ? min(atmosphereHit.y, groundHit.x) : atmosphereHit.y;
    float stepSize = max(rayEnd - rayStart, 0.0) / float(kPrimarySteps);

    float mu = dot(rayDir, sunDir);
    // Optical depth / extinction below still use the real rayDir/sunDir positions (so sun
    // elevation still correctly darkens/tints the ground), only the phase functions' angular
    // dependence is neutralized here.
    float phaseR = rayleighPhase(isotropicPhase ? 0.0 : mu);
    float phaseM = miePhase(isotropicPhase ? 0.0 : mu, kMieAnisotropy);

    float3 totalRayleigh = float3(0.0);
    float3 totalMie = float3(0.0);
    float3 opticalDepth = float3(0.0); // x=Rayleigh, y=Mie, z=ozone, accumulated along the view ray

    float t = rayStart;
    for (int i = 0; i < kPrimarySteps; i++) {
        float3 samplePos = rayOrigin + rayDir * (t + stepSize * 0.5);
        float heightKm = length(samplePos) - kPlanetRadiusKm;

        float3 stepDensity = float3(rayleighDensity(heightKm), mieDensity(heightKm), ozoneDensity(heightKm)) * stepSize;
        opticalDepth += stepDensity;

        float3 sunOpticalDepth = lightMarchOpticalDepth(samplePos, sunDir);
        float3 tau = kRayleighScattering * (opticalDepth.x + sunOpticalDepth.x)
            + kMieExtinction * (opticalDepth.y + sunOpticalDepth.y)
            + kOzoneAbsorption * (opticalDepth.z + sunOpticalDepth.z);
        float3 attenuation = exp(-tau);

        totalRayleigh += stepDensity.x * attenuation;
        totalMie += stepDensity.y * attenuation;

        t += stepSize;
    }

    float3 inScattered = sunIntensity * sunColor
        * (phaseR * kRayleighScattering * totalRayleigh + phaseM * kMieScattering * totalMie);

    // Sun disk: attenuate direct sun illuminance by the transmittance already accumulated along
    // the view ray (valid here because rayDir ≈ sunDir wherever the disk term is non-zero).
    float sunDisk = smoothstep(kSunDiskCosAngle - 0.0005, kSunDiskCosAngle + 0.0005, mu);
    float3 viewTransmittance = exp(-(kRayleighScattering * opticalDepth.x + kMieExtinction * opticalDepth.y + kOzoneAbsorption * opticalDepth.z));

    // The disk/glow above are driven purely by the angle between the view ray and the sun
    // direction, so without these two gates they'd render in places they physically can't be
    // seen from. First: the sun itself can be below the horizon while a *level* view ray still
    // points close enough to it (mu inside the disk/glow's angular radius) -- rayOrigin always
    // sits on the planet-centered space's +Y axis here, so sunDir.y is a reliable proxy for "sun
    // above the local horizon"; fade smoothly across zero so the sun sets rather than pops.
    float sunVisibility = smoothstep(-0.02, 0.02, sunDir.y);

    // Second, and independently: the *view ray* itself can point at the ground (groundHit.x > 0,
    // already used above to clip the raymarch) while still being within angular range of a sun
    // that's above the horizon off to the side -- the ground blocks it regardless of that angular
    // proximity, so this is a hard cutoff exactly at the horizon line rather than a soft fade.
    float groundOcclusion = groundHit.x > 0.0 ? 0.0 : 1.0;

    float sunVisibleFactor = includeSunDisk ? sunVisibility * groundOcclusion : 0.0;

    float3 sunDiskColor = sunDisk * sunVisibleFactor * sunIntensity * sunColor * viewTransmittance;

    // Soft corona: a much wider, gently-falling glow around the disk (see kSunGlowExponent/Strength
    // above), giving the sun a bloom-like halo even with the HDR bloom post-process turned off.
    float sunGlow = pow(saturate(mu), kSunGlowExponent);
    float3 sunGlowColor = sunGlow * sunVisibleFactor * kSunGlowStrength * sunIntensity * sunColor * viewTransmittance;

    // Cheap multiple-scattering approximation. Single scattering alone makes the horizon read
    // unrealistically saturated/warm at every sun elevation: it only accounts for light that
    // reaches the eye directly, and the VIEW ray's path length through the dense low atmosphere
    // (not the sun's position) is what drives that -- looking toward the horizon is a long path
    // regardless of where the sun is. In reality most of the blue "lost" along that path re-enters
    // the eye after further bounces off other air molecules, which is what keeps a real midday
    // horizon looking pale blue/white rather than orange. We approximate that re-entry as an
    // isotropic fill using Rayleigh's *average* (near wavelength-independent) response instead of
    // its full per-channel spread, scaled by how much of the view path was already extincted, so
    // it fills back a pale, mostly-neutral glow rather than literally simulating extra bounces.
    float rayleighAverage = (kRayleighScattering.x + kRayleighScattering.y + kRayleighScattering.z) / 3.0;
    float3 multiScatter = sunIntensity * sunColor * rayleighAverage * kMultiScatterStrength
        * (float3(1.0) - viewTransmittance);

    return inScattered + sunDiskColor + sunGlowColor + multiScatter;
}

fragment float4 fragmentSkyShader(
    SkyVertexOutput in [[stage_in]],
    constant SkyUniforms &skyUniforms [[buffer(skyPassUniformIndex)]]
) {
    float3 rayDir = normalize(in.rayDir);
    float3 sunDir = normalize(skyUniforms.sunDirection);

    // World Y is assumed to be meters above a ground plane at y = 0. Converted to kilometers and
    // offset by the planet radius so the raymarch runs in planet-centered space; XZ position is
    // intentionally ignored (flat local-frame simplification -- the engine has no georeferencing,
    // so only height above "ground" and the sun angle matter for the atmosphere's appearance).
    float cameraHeightKm = max(skyUniforms.cameraPosition.y, 0.0) * 0.001 + kMinCameraHeightKm;
    float3 rayOrigin = float3(0.0, kPlanetRadiusKm + cameraHeightKm, 0.0);

    // Rays that hit the ground (no real ground geometry backs this pass -- it's pure background)
    // would otherwise return near-black: computeSkyColor's raymarch gets clipped to the short
    // segment between the camera and the ground hit, which accumulates barely any in-scattered
    // light. Approximate the ground instead as a darkened version of the sky's own horizon color
    // in that azimuthal direction -- i.e. level the ray off (keep its XZ heading, zero its Y) so
    // computeSkyColor evaluates the same horizon it renders directly above this point, which
    // never intersects the ground and so integrates the full atmosphere like any other sky ray.
    float2 groundHit = raySphereIntersect(rayOrigin, rayDir, kPlanetRadiusKm);
    float3 effectiveRayDir = rayDir;
    if (groundHit.x > 0.0) {
        float2 horizontal = float2(rayDir.x, rayDir.z);
        float horizontalLength = length(horizontal);
        if (horizontalLength > 1e-4) {
            effectiveRayDir = float3(horizontal.x, 0.0, horizontal.y) / horizontalLength;
        }
    }

    bool isGround = groundHit.x > 0.0;
    float3 color = computeSkyColor(rayOrigin, effectiveRayDir, sunDir, skyUniforms.sunColor, skyUniforms.sunIntensity, !isGround, isGround);

    if (isGround) {
        color *= kGroundDarkening;
    }

    return float4(color, 1.0);
}
