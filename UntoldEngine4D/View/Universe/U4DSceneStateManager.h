//
//  U4DSceneStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneStateManager_hpp
#define U4DSceneStateManager_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

class U4DScene;

namespace U4DEngine {

    class U4DSceneStateManager {
        
    private:
        
        U4DScene *scene;
        
        U4DSceneStateInterface *previousState;

        U4DSceneStateInterface *currentState;
        
        U4DSceneStateInterface *nextState;
        
        bool changeStateRequest;
        
    public:
        
        U4DSceneStateManager(U4DScene *uScene);
        
        ~U4DSceneStateManager();
        
        void changeState(U4DSceneStateInterface *uState);
        
        void update(double dt);
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        bool isSafeToChangeState();
        
        void safeChangeState(U4DSceneStateInterface *uState);
        
        U4DSceneStateInterface *getCurrentState();
        
    };

}


#endif /* U4DSceneStateManager_hpp */
