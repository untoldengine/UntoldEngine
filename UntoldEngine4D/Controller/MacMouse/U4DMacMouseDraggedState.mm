//
//  U4DMacMouseDraggedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseDraggedState.h"
#include "U4DControllerInterface.h"
#include "U4DMacMouseIdleState.h"
#include "U4DMacMouseStateManager.h"
#include "U4DNumerical.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DMacMouseDraggedState* U4DMacMouseDraggedState::instance=0;
    
    U4DMacMouseDraggedState::U4DMacMouseDraggedState(){
        
    }
    
    U4DMacMouseDraggedState::~U4DMacMouseDraggedState(){
        
    }
    
    U4DMacMouseDraggedState* U4DMacMouseDraggedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseDraggedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseDraggedState::enter(U4DMacMouse *uMacMouse){
        
        
    }
    
    void U4DMacMouseDraggedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        U4DNumerical numerical;
        
        U4DEngine::U4DVector2n mouseDirection=uMacMouse->dataPosition-uMacMouse->previousDataPosition;
        
        //Test if the mouse has stopped by using a Recency Weithted Average
        
        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.90;
        
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
    
    void U4DMacMouseDraggedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
