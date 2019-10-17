//
//  U4DMacMouseDeltaMovedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseDeltaMovedState.h"
#include "U4DControllerInterface.h"
#include "U4DMacMouseIdleState.h"
#include "U4DMacMouseStateManager.h"
#include "U4DNumerical.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DMacMouseDeltaMovedState* U4DMacMouseDeltaMovedState::instance=0;
    
    U4DMacMouseDeltaMovedState::U4DMacMouseDeltaMovedState():mouseSlowFactor(1.0){
        
    }
    
    U4DMacMouseDeltaMovedState::~U4DMacMouseDeltaMovedState(){
        
    }
    
    U4DMacMouseDeltaMovedState* U4DMacMouseDeltaMovedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseDeltaMovedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseDeltaMovedState::enter(U4DMacMouse *uMacMouse){
        
        mouseSlowFactor=1.0;
    }
    
    void U4DMacMouseDeltaMovedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        U4DNumerical numerical;
        
        U4DEngine::U4DVector2n mouseDelta(uMacMouse->mouseAxisDelta.x,uMacMouse->mouseAxisDelta.y);
        
        float biasMotionAccumulator=0.90;
        float biasSlowFactorAccumulator=0.50;
        
        motionDeltaAccumulator=motionDeltaAccumulator*biasMotionAccumulator+mouseDelta*(1.0-biasMotionAccumulator);
        
        //The slow down factor is used to decrease the speed of the mouse
        mouseSlowFactor=mouseSlowFactor*biasSlowFactorAccumulator+dt*(1.0-biasSlowFactorAccumulator);
        
        if (numerical.areEqual(mouseSlowFactor, U4DEngine::timeStep, U4DEngine::zeroEpsilon)) {

            uMacMouse->getStateManager()->changeState(U4DMacMouseIdleState::sharedInstance());

        }
        
        uMacMouse->mouseAxisDelta=motionDeltaAccumulator;
        
        uMacMouse->previousMouseAxisDelta=mouseDelta;
        
        if (uMacMouse->pCallback!=NULL) {
            uMacMouse->action();
        }
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    
    }
    
    void U4DMacMouseDeltaMovedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
