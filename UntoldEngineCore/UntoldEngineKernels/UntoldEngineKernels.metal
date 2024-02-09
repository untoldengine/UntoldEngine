//
//  UntoldEngineKernels.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/29/23.
//

#include <metal_stdlib>
using namespace metal;

#include "../Shaders/ShaderStructs.metal"
#include "../Shaders/ShadersUtils.metal"
#include "../Shaders/ComputeHelperFunctions.metal"
#include "../Shaders/voxelShader.metal"
#include "../Shaders/shadowShader.metal"
#include "../Shaders/GridShader.metal"
#include "../Shaders/intersectionCompute.metal"
#include "../Shaders/feedbackVoxelShader.metal"
#include "../Shaders/planeShader.metal"
#include "../Shaders/removeAllCompute.metal"
#include "../Shaders/serializeCompute.metal"
#include "../Shaders/environmentShader.metal"
#include "../Shaders/compositeShader.metal"
#include "../Shaders/iblPreFilterShaders.metal"
