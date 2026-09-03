//
//  UntoldEngineKernels.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;

#include <TargetConditionals.h>

#include "../Shaders/ShadersUtils.metal"
#include "../Shaders/shadowShader.metal"
#include "../Shaders/GridShader.metal"
#include "../Shaders/SkyShader.metal"
#include "../Shaders/geometryShader.metal"
#include "../Shaders/environmentShader.metal"
#include "../Shaders/compositeShader.metal"
#include "../Shaders/iblPreFilterShaders.metal"
#include "../Shaders/modelShader.metal"
#include "../Shaders/postprocessShader.metal"
#include "../Shaders/tonemapShader.metal"
#include "../Shaders/preCompShader.metal"
#include "../Shaders/ColorGradingShader.metal"
#include "../Shaders/BlurShader.metal"
#include "../Shaders/ColorCorrectionShader.metal"
#include "../Shaders/BloomThresholdShader.metal"
#include "../Shaders/BloomCompositeShader.metal"
#include "../Shaders/VignetteShader.metal"
#include "../Shaders/ChromaticShader.metal"
#include "../Shaders/DoFShader.metal"
#include "../Shaders/SSAOShader.metal"
#include "../Shaders/LightShader.metal"
#include "../Shaders/TransparencyShader.metal"
#include "../Shaders/WireframeShader.metal"
#include "../Shaders/SSAOBlurShader.metal"
#include "../Shaders/FrustumCullingCompute.metal"
#include "../Shaders/HZBCompute.metal"
#include "../Shaders/ARShader.metal"
#include "../Shaders/SSAOBilateralBlurShader.metal"
#include "../Shaders/SSAOUpsampleShader.metal"
#include "../Shaders/spatialDebugShader.metal"
#include "../Shaders/FXAAShader.metal"
#include "../Shaders/SMAAShader.metal"
// Gaussian kernels
#include "../Shaders/BitonicSort.metal"
#include "../Shaders/DeviceRadixSort.metal"
#include "../Shaders/Gaussians.metal"

// Shaders used by editor when in edit mode- These pipeline is ignored by iOS since iOS will never be in edit mode
#include "../Shaders/OutlineShader.metal"
#include "../Shaders/raymodelIntersect.metal"
#include "../Shaders/LightVisualShader.metal"
#include "../Shaders/debugShader.metal"
#include "../Shaders/GizmoShader.metal"

#include "../Shaders/LookShader.metal"
#include "../Shaders/OutputTransformShader.metal"
