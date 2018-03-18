//
//  U4DMacMouseActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseActiveState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacMouseActiveState* U4DMacMouseActiveState::instance=0;
    
    U4DMacMouseActiveState::U4DMacMouseActiveState(){
        
    }
    
    U4DMacMouseActiveState::~U4DMacMouseActiveState(){
        
    }
    
    U4DMacMouseActiveState* U4DMacMouseActiveState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseActiveState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseActiveState::enter(U4DMacMouse *uMacMouse){
        
        
    }
    
    void U4DMacMouseActiveState::execute(U4DMacMouse *uMacMouse, double dt){
        
        U4DEngine::U4DVector3n mouseAxis(uMacMouse->mouseAxis.x,uMacMouse->mouseAxis.y, 0.0);
        
        U4DEngine::U4DVector3n absoluteMouseAxis=mouseAxis-uMacMouse->initialDataPosition;
        
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
        
        uMacMouse->initialDataPosition=mouseAxis;
        
        uMacMouse->dataPosition=absoluteMouseAxis;
        
        uMacMouse->dataMagnitude=absoluteMouseAxis.magnitude();
        
        if (uMacMouse->pCallback!=NULL) {
            uMacMouse->action();
        }
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseActiveState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
