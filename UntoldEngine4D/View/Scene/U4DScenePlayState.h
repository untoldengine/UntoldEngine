//
//  U4DScenePlayState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/12/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScenePlayState_hpp
#define U4DScenePlayState_hpp

#include <stdio.h>
#include "U4DSceneStateInterface.h"

namespace U4DEngine {

    /**
    @ingroup scene
    @brief The U4DScenePlayState class represents the scene Idle state.
    */
    class U4DScenePlayState:public U4DSceneStateInterface {

    private:
        
        bool safeToChangeState;
        
        U4DScenePlayState();
        
        ~U4DScenePlayState();
        
    public:
        
        static U4DScenePlayState* instance;
        
        static U4DScenePlayState* sharedInstance();
        
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
#endif /* U4DScenePlayState_hpp */
