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

    /**
    @ingroup scene
    @brief The U4DSceneStateInterface class represents the scene state interface.
    */
    class U4DSceneStateInterface {

    public:
        
        /**
        @brief Scene Interface destructor
        */
        virtual ~U4DSceneStateInterface(){};
        
        /**
        @brief enters new state
        @param uScene scene to enter into new state
        */
        virtual void enter(U4DScene *uScene)=0;
        
        /**
        @brief executes current state
        @param uScene scene to execute
        @param dt game tick
        */
        virtual void execute(U4DScene *uScene, double dt)=0;
        
        /**
        @brief Renders current scene
        @param uScene scene to render
        @param uRenderEncoder metal render encoder
        */
        virtual void render(U4DScene *uScene,id <MTLCommandBuffer> uCommandBuffer)=0;
        
        
        
        /**
        @brief exits current state
        @param uScene scene to exit
        */
        virtual void exit(U4DScene *uScene)=0;
        
        /**
        @brief true if is safe to change states
        @param uScene current scene
        */
        virtual bool isSafeToChangeState(U4DScene *uScene)=0;
    
    };

}


#endif /* U4DSceneStateInterface_hpp */
