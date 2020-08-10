//
//  U4DSceneIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneIdleState_hpp
#define U4DSceneIdleState_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

namespace U4DEngine {

    class U4DSceneIdleState:public U4DSceneStateInterface {

    private:
        
        U4DSceneIdleState();
        
        ~U4DSceneIdleState();
        
    public:
        
        static U4DSceneIdleState* instance;
        
        static U4DSceneIdleState* sharedInstance();
        
        void enter(U4DScene *uScene);
        
        void execute(U4DScene *uScene, double dt);
        
        void render(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void renderShadow(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        void exit(U4DScene *uScene);
        
        bool isSafeToChangeState(U4DScene *uScene);
        
    };

}

#endif /* U4DSceneIdleState_hpp */
