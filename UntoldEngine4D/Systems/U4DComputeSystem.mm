//
//  U4DComputeSystem.cpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 4/16/23.
//

#include "U4DComputeSystem.h"

#include <string>

extern U4DEngine::RendererInfo renderInfo;

namespace U4DEngine{

bool initCompute(ComputePipeline uComputePipeline, std::string uKernelName){
    
    NSString* kernelPath = [NSString stringWithUTF8String:uKernelName.c_str()];
    
    NSError *error;
    
    //create a library
    id<MTLLibrary> defaultLibrary=[renderInfo.device newDefaultLibrary];
    
    //create a kernel
    id<MTLFunction> kernel=[defaultLibrary newFunctionWithName:kernelPath];
    
    //Create a compute pipeline state object
    uComputePipeline.pipelineState=[renderInfo.device newComputePipelineStateWithFunction:kernel error:&error];
    
    if(!uComputePipeline.pipelineState){
        std::string errorDesc= std::string([error.localizedDescription UTF8String]);
        
        printf("Success: The Compute pipeline was unable to be created. %s",errorDesc.c_str());
    }

        printf("Success: The Compute pipeline was properly configured");
        
        uComputePipeline.success=true;
        
        return true;
    
}
void executeCompute(id<MTLRenderCommandEncoder> uRenderEncoder){
    
}

}
