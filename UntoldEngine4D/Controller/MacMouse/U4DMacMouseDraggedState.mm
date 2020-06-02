//
//  U4DMacMouseDraggedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseDraggedState.h"
#include "U4DControllerInterface.h"

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
        
        U4DEngine::U4DVector2n absoluteMouseAxis=uMacMouse->dataPosition-uMacMouse->previousDataPosition;
        
        //make sure that the mouse drag is not too close to its initial position.
        if (absoluteMouseAxis.magnitude()<1.0) {
            
            absoluteMouseAxis=uMacMouse->dataPosition;
            
        }
        
        absoluteMouseAxis.normalize();
        
        if (uMacMouse->dataPosition.dot(absoluteMouseAxis)<-0.9) {
            
            uMacMouse->directionReversal=true;
            
        }else{
            uMacMouse->directionReversal=false;
            
        }
        
        uMacMouse->previousDataPosition=uMacMouse->dataPosition;
        
        uMacMouse->dataPosition=absoluteMouseAxis;
        
        uMacMouse->dataMagnitude=absoluteMouseAxis.magnitude();
        
        
        uMacMouse->action();
        
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseDraggedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
