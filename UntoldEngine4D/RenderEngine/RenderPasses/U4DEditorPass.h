//
//  U4DEditorPass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/29/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DImGUIPass_hpp
#define U4DImGUIPass_hpp

#include <stdio.h>
#include "U4DRenderPass.h"
#include "U4DRenderEntity.h"
#include "U4DRenderPassInterface.h"


namespace U4DEngine{

class U4DEditorPass: public U4DRenderPass{
    
private:
    
    
public:
    
    U4DEditorPass(std::string uPipelineName);
    
    ~U4DEditorPass();
    
    void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass);
    
};

}
#endif /* U4DImGUIPass_hpp */
