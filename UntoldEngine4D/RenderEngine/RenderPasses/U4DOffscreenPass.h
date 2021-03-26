//
//  U4DOffscreenPass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DOffscreenPass_hpp
#define U4DOffscreenPass_hpp

#include <stdio.h>
#include "U4DRenderPass.h"
#include "U4DRenderEntity.h"
#include "U4DRenderPassInterface.h"

namespace U4DEngine{

class U4DOffscreenPass: public U4DRenderPass{
    
private:
    
public:
    
    U4DOffscreenPass(std::string uPipelineName);
    
    ~U4DOffscreenPass();
    
    void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass);
    
};

}
#endif /* U4DOffscreenPass_hpp */
