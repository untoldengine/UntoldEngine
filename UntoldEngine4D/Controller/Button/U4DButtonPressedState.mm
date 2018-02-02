//
//  U4DButtonPressedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DButtonPressedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {

    U4DButtonPressedState* U4DButtonPressedState::instance=0;
    
    U4DButtonPressedState::U4DButtonPressedState(){
        
    }
    
    U4DButtonPressedState::~U4DButtonPressedState(){
        
    }
    
    U4DButtonPressedState* U4DButtonPressedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DButtonPressedState();
        }
        
        return instance;
        
    }
    
    void U4DButtonPressedState::enter(U4DButton *uButton){
        
        uButton->buttonImages.changeImage();
        
        if (uButton->pCallback!=NULL) {
            uButton->action();
        }
        
        
        if (uButton->controllerInterface !=NULL) {
            uButton->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DButtonPressedState::execute(U4DButton *uButton, double dt){
        
        
    }
    
    void U4DButtonPressedState::exit(U4DButton *uButton){
        
    }

}
