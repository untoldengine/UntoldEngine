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
#include "../Shaders/shadowShader.metal"
#include "../Shaders/GridShader.metal"
#include "../Shaders/geometryShader.metal"
#include "../Shaders/environmentShader.metal"
#include "../Shaders/compositeShader.metal"
#include "../Shaders/iblPreFilterShaders.metal"
#include "../Shaders/debugShader.metal"
#include "../Shaders/modelShader.metal"
#include "../Shaders/postprocessShader.metal"
#include "../Shaders/lightingShader.metal"
#include "../Shaders/tonemapShader.metal"
#include "../Shaders/raytracer.metal"
#include "../Shaders/raymodelIntersect.metal"
#include "../Shaders/preCompShader.metal"
#include "../Shaders/rayCompositeShader.metal"
#include "../Shaders/clearRTXTexture.metal"
#include "../Shaders/paintLightShader.metal"
#include "../Shaders/paintLightCompositeShader.metal"
#include "../Shaders/hdrtohdrShader.metal"
#include "../Shaders/paintLightBaseShader.metal"
