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

    /**
    @ingroup scene
    @brief The U4DSceneIdleState class represents the scene Idle state.
    */
    class U4DSceneIdleState:public U4DSceneStateInterface {

    private:
        
        U4DSceneIdleState();
        
        ~U4DSceneIdleState();
        
    public:
        
        static U4DSceneIdleState* instance;
        
        static U4DSceneIdleState* sharedInstance();
        
        /**
        @brief enters new state
        @param uScene scene to enter into new state
        */
        void enter(U4DScene *uScene);
        
        /**
        @brief executes current state
        @param uScene scene to execute
        @param dt game tick
        */
        void execute(U4DScene *uScene, double dt);
        
        /**
        @brief Renders current scene
        @param uScene scene to render
        @param uRenderEncoder metal render encoder
        */
        void render(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
        @brief Renders current scene shadows
        @param uScene scene to render
        @param uRenderShadowEncoder metal render encoder
        @param uShadowTexture shadow textures
        */
        void renderShadow(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        /**
         @todo document this
         */
        void renderOffscreen(U4DScene *uScene, id <MTLRenderCommandEncoder> uOffscreenRenderEncoder, id<MTLTexture> uOffscreenTexture);
        
        /**
        @brief exits current state
        @param uScene scene to exit
        */
        void exit(U4DScene *uScene);
        
        /**
        @brief true if is safe to change states
        @param uScene current scene
        */
        bool isSafeToChangeState(U4DScene *uScene);
        
    };

}

#endif /* U4DSceneIdleState_hpp */
