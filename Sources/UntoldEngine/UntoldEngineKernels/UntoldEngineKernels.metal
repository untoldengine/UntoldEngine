#include <metal_stdlib>
using namespace metal;

#include <TargetConditionals.h>

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
#include "../Shaders/tonemapShader.metal"
#include "../Shaders/preCompShader.metal"
#include "../Shaders/LightVisualShader.metal"
#include "../Shaders/ColorGradingShader.metal"
#include "../Shaders/BlurShader.metal"
#include "../Shaders/ColorCorrectionShader.metal"
#include "../Shaders/BloomThresholdShader.metal"
#include "../Shaders/BloomCompositeShader.metal"
#include "../Shaders/VignetteShader.metal"
#include "../Shaders/ChromaticShader.metal"
#include "../Shaders/DoFShader.metal"
#include "../Shaders/SSAOShader.metal"
#include "../Shaders/GizmoShader.metal"
#include "../Shaders/LightShader.metal"
#include "../Shaders/SSAOBlurShader.metal"
#include "../Shaders/FrustumCullingCompute.metal"

#if TARGET_OS_OSX

#include "../Shaders/OutlineShader.metal"
#include "../Shaders/raymodelIntersect.metal"
#endif
