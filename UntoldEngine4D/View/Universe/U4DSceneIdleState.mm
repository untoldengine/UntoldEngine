//
//  U4DSceneIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneIdleState.h"

namespace U4DEngine {

    U4DSceneIdleState* U4DSceneIdleState::instance=0;

    U4DSceneIdleState::U4DSceneIdleState(){

    }

    U4DSceneIdleState::~U4DSceneIdleState(){

    }

    U4DSceneIdleState* U4DSceneIdleState::sharedInstance(){

    if (instance==0) {
        instance=new U4DSceneIdleState();
    }

    return instance;

    }

    void U4DSceneIdleState::enter(U4DScene *uScene){

    }
        
    void U4DSceneIdleState::execute(U4DScene *uScene, double dt){
        
    }

    void U4DSceneIdleState::render(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderEncoder){
        
    }
        
    void U4DSceneIdleState::renderShadow(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
    }
            
    
    void U4DSceneIdleState::exit(U4DScene *uScene){
        
    }

    bool U4DSceneIdleState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
