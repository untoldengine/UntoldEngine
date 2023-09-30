//
//  U4DComputeSystem.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 4/16/23.
//

#ifndef U4DComputeSystem_hpp
#define U4DComputeSystem_hpp

#include <stdio.h>
#import <MetalKit/MetalKit.h>
#include "U4DComponents.h"

namespace U4DEngine{

bool initCompute(ComputePipeline uComputePipeline, std::string uKernelName);
void executeCompute(id<MTLRenderCommandEncoder> uRenderEncoder);

}
#endif /* U4DComputeSystem_hpp */
