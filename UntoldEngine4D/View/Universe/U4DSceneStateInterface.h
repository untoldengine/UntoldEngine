//
//  U4DSceneStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneStateInterface_hpp
#define U4DSceneStateInterface_hpp

#include <stdio.h>
#include "U4DScene.h"

namespace U4DEngine {

    class U4DSceneStateInterface {

    public:
        
        virtual ~U4DSceneStateInterface(){};
        
        virtual void enter(U4DScene *uScene)=0;
        
        virtual void execute(U4DScene *uScene, double dt)=0;
        
        virtual void render(U4DScene *uScene,id <MTLRenderCommandEncoder> uRenderEncoder)=0;
        
        virtual void renderShadow(U4DScene *uScene,id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture)=0;
        
        virtual void exit(U4DScene *uScene)=0;
        
        virtual bool isSafeToChangeState(U4DScene *uScene)=0;
    
    };

}


#endif /* U4DSceneStateInterface_hpp */
