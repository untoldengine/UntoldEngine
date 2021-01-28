//
//  U4DFinalPass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFinalPass_hpp
#define U4DFinalPass_hpp

#include <stdio.h>
#include "U4DRenderPass.h"
#include "U4DRenderEntity.h"
#include "U4DRenderPassInterface.h"

namespace U4DEngine{

class U4DFinalPass: public U4DRenderPass{
    
private:
    
public:
    
    U4DFinalPass(std::string uPipelineName);
    
    ~U4DFinalPass();
    
    void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass);
    
};

}
#endif /* U4DFinalPass_hpp */
