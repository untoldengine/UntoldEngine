//
//  U4DEditorStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/26/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DEditorStateManager.h"
#include "U4DEditorStateInterface.h"
#include "U4DEditor.h"

namespace U4DEngine {

U4DEditorStateManager::U4DEditorStateManager(U4DEditor *uEditor):editor(uEditor),currentState(nullptr),previousState(nullptr){
    
}

U4DEditorStateManager::~U4DEditorStateManager(){
    
}

void U4DEditorStateManager::showEditor(){
    
    currentState->execute(editor);
}

void U4DEditorStateManager::changeState(U4DEditorStateInterface *uState){
    
    if(currentState!=uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(editor);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(editor);

    }
    
}

U4DEditorStateInterface *U4DEditorStateManager::getCurrentState(){
    return currentState;
}

U4DEditorStateInterface *U4DEditorStateManager::getPreviousState(){
    return previousState;
}

}
