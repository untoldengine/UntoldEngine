//
//  U4DMacMouseMovedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseMovedState.h"
#include "U4DControllerInterface.h"
#include "U4DMacMouseIdleState.h"
#include "U4DMacMouseStateManager.h"
#include "U4DNumerical.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DMacMouseMovedState* U4DMacMouseMovedState::instance=0;
    
    U4DMacMouseMovedState::U4DMacMouseMovedState(){
        
    }
    
    U4DMacMouseMovedState::~U4DMacMouseMovedState(){
        
    }
    
    U4DMacMouseMovedState* U4DMacMouseMovedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseMovedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseMovedState::enter(U4DMacMouse *uMacMouse){
        
        
    }
    
    void U4DMacMouseMovedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        U4DNumerical numerical;
        
        U4DEngine::U4DVector2n mouseDirection=uMacMouse->dataPosition-uMacMouse->previousDataPosition;
        
        //Test if the mouse has stopped by using a Recency Weithted Average
        
        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.0;
        
        uMacMouse->motionAccumulator=uMacMouse->motionAccumulator*biasMotionAccumulator+uMacMouse->dataPosition*(1.0-biasMotionAccumulator);
        
        
        float zeroValue=0.0;
        
        //if the motion accumulator is closed to zero, then it means the mouse has stopped
        if (numerical.areEqual(mouseDirection.magnitude(), zeroValue, U4DEngine::zeroEpsilon)) {
            
            uMacMouse->getStateManager()->changeState(U4DMacMouseIdleState::sharedInstance());

        }
        
        uMacMouse->previousDataPosition=uMacMouse->dataPosition;
        
        uMacMouse->dataPosition=uMacMouse->motionAccumulator;
        
        uMacMouse->dataMagnitude=uMacMouse->motionAccumulator.magnitude();
        
        
        uMacMouse->action();
        
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseMovedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
