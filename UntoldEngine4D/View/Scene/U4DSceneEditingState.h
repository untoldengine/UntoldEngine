//
//  U4DSceneEditingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneEditingState_hpp
#define U4DSceneEditingState_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

namespace U4DEngine {

    /**
    @ingroup scene
    @brief The U4DSceneEditingState class represents the scene Idle state.
    */
    class U4DSceneEditingState:public U4DSceneStateInterface {

    private:
        
        bool safeToChangeState;
        
        bool didWorldInit;
        
        static U4DSceneEditingState* instance;
        
        U4DSceneEditingState();
        
        ~U4DSceneEditingState();
        
    public:
        
        static U4DSceneEditingState* sharedInstance();
        
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
        void render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer);
        
        
        
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
#endif /* U4DSceneEditingState_hpp */
