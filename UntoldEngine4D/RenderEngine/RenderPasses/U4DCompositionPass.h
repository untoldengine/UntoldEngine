//
//  U4DCompositionPass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCompositionPass_hpp
#define U4DCompositionPass_hpp

#include <stdio.h>
#include "U4DRenderPass.h"
#include "U4DRenderEntity.h"
#include "U4DRenderPassInterface.h"

namespace U4DEngine{

class U4DCompositionPass: public U4DRenderPass{
    
private:
    
public:
    
    U4DCompositionPass(std::string uPipelineName);
    
    ~U4DCompositionPass();
    
    void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass);
    
};

}
#endif /* U4DCompositionPass_hpp */
