//
//  U4DSceneLoadingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneLoadingState_hpp
#define U4DSceneLoadingState_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

namespace U4DEngine {

    class U4DSceneLoadingState:public U4DSceneStateInterface {

    private:
        
        U4DSceneLoadingState();
        
        ~U4DSceneLoadingState();
        
        bool safeToChangeState;
        
    public:
        
        static U4DSceneLoadingState* instance;
        
        static U4DSceneLoadingState* sharedInstance();
        
        void enter(U4DScene *uScene);
        
        void execute(U4DScene *uScene, double dt);
        
        void render(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void renderShadow(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        void exit(U4DScene *uScene);
        
        bool isSafeToChangeState(U4DScene *uScene);
        
    };

}
#endif /* U4DSceneLoadingState_hpp */
