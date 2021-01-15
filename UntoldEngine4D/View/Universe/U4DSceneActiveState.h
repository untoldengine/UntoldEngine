//
//  U4DSceneActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneActiveState_hpp
#define U4DSceneActiveState_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

namespace U4DEngine {

    /**
    @ingroup scene
    @brief The U4DSceneActiveState class represents the scene Active state.
    */
    class U4DSceneActiveState:public U4DSceneStateInterface {

    private:
        
        U4DSceneActiveState();
        
        ~U4DSceneActiveState();
        
        bool safeToChangeState;
        
    public:
        
        static U4DSceneActiveState* instance;
        
        static U4DSceneActiveState* sharedInstance();
        
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
#endif /* U4DSceneActiveState_hpp */
