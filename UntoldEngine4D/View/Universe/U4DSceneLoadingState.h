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

    /**
    @ingroup scene
    @brief The U4DSceneLoadingState class represents the scene Loading state.
    */
    class U4DSceneLoadingState:public U4DSceneStateInterface {

    private:
        
        U4DSceneLoadingState();
        
        ~U4DSceneLoadingState();
        
        bool safeToChangeState;
        
    public:
        
        static U4DSceneLoadingState* instance;
        
        static U4DSceneLoadingState* sharedInstance();
        
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
#endif /* U4DSceneLoadingState_hpp */
