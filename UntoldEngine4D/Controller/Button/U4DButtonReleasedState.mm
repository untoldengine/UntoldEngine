//
//  U4DButtonReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DButtonReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DButtonReleasedState* U4DButtonReleasedState::instance=0;
    
    U4DButtonReleasedState::U4DButtonReleasedState(){
        
    }
    
    U4DButtonReleasedState::~U4DButtonReleasedState(){
        
    }
    
    U4DButtonReleasedState* U4DButtonReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DButtonReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DButtonReleasedState::enter(U4DButton *uButton){
        
        uButton->buttonImages.changeImage();
        
        if (uButton->pCallback!=NULL) {
            uButton->action();
        }
        
        
        if (uButton->controllerInterface !=NULL) {
            uButton->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DButtonReleasedState::execute(U4DButton *uButton, double dt){
        
        
    }
    
    void U4DButtonReleasedState::exit(U4DButton *uButton){
        
    }
    
}
