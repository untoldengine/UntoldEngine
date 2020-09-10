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

    /**
    @ingroup scene
    @brief The U4DSceneStateManager class represents the scene state manager. It manages the states of the scenes.
    */
    class U4DSceneStateManager {
        
    private:
        
        /**
         @brief pointer to current scene
         */
        U4DScene *scene;
        
        /**
         @brief previous scene state
         */
        U4DSceneStateInterface *previousState;

        /**
         @brief current scene state
         */
        U4DSceneStateInterface *currentState;
        
        /**
         @brief next scene state
         */
        U4DSceneStateInterface *nextState;
        
        /**
         @brief set to true if there is a request to change scene
         */
        bool changeStateRequest;
        
    public:
        
        /**
         @brief scene state manager constructor
         @param uScene current scene
         */
        U4DSceneStateManager(U4DScene *uScene);
        
        /**
         @brief scene state manager destructor
         */
        ~U4DSceneStateManager();
        
        /**
         @brief changes the state of the scene
         @param uState scene state to change to
         */
        void changeState(U4DSceneStateInterface *uState);
        
        /**
         @brief updates the scene
         @param dt game tick
         */
        void update(double dt);
        
        /**
        @brief Renders current scene
        @param uScene scene to render
        @param uRenderEncoder metal render encoder
        */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
        @brief Renders current scene shadows
        @param uScene scene to render
        @param uRenderShadowEncoder metal render encoder
        @param uShadowTexture shadow textures
        */
        void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        /**
         @brief sets to true if it is safe to change the scene state
         */
        bool isSafeToChangeState();
        
        /**
         @brief safe to change scene state
         @param uState scene state to change to
         */
        void safeChangeState(U4DSceneStateInterface *uState);
        
        /**
         @brief returns the current scene state
         */
        U4DSceneStateInterface *getCurrentState();
        
    };

}


#endif /* U4DSceneStateManager_hpp */
