//
//  U4DKeyboardInput.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DKeyboardController.h"

namespace U4DEngine {
    
    //constructor
    U4DKeyboardController::U4DKeyboardController(){
        
    
    }
    
    //destructor
    U4DKeyboardController::~U4DKeyboardController(){
        
    }

    void U4DKeyboardController::init(){
        
        //create the mac key 'w' object
        keyW=new U4DMacKey(U4DEngine::macKeyW,this);
        keyA=new U4DMacKey(U4DEngine::macKeyA,this);
        keyD=new U4DMacKey(U4DEngine::macKeyD,this);
        keyS=new U4DMacKey(U4DEngine::macKeyS, this);
        macKeyShift=new U4DMacKey(U4DEngine::macShiftKey,this);
        arrowKey=new U4DMacArrowKey(U4DEngine::macArrowKey,this);
        
        mouseLeftButton=new U4DMacMouse(U4DEngine::mouseLeftButton,this);
        macMouse=new U4DMacMouse(U4DEngine::mouse,this);
        
        registerInputEntity(keyW);
        registerInputEntity(keyA);
        registerInputEntity(keyD);
        registerInputEntity(keyS);
        registerInputEntity(macKeyShift);
        registerInputEntity(arrowKey);
        
        registerInputEntity(mouseLeftButton);
        registerInputEntity(macMouse);
        
    }
    
    void U4DKeyboardController::getUserInputData(unichar uCharacter, INPUTELEMENTACTION uInputAction){
        
        U4DVector2n pos(0.0,0.0);
        
        if(uCharacter=='w' || uCharacter=='W'){

            changeState(U4DEngine::macKeyW, uInputAction, pos);

        }

        if(uCharacter=='a' || uCharacter=='A'){

            changeState(U4DEngine::macKeyA, uInputAction, pos);

        }
        
        
        if(uCharacter=='d' || uCharacter=='D'){
            
            changeState(U4DEngine::macKeyD, uInputAction, pos);
        }
    
        if(uCharacter=='s' || uCharacter=='S'){
            changeState(U4DEngine::macKeyS, uInputAction, pos);
        }
    
        if(uCharacter=='1'){
            changeState(U4DEngine::macKey1, uInputAction, pos);
        }
    
        if(uCharacter=='2'){
            changeState(U4DEngine::macKey2, uInputAction, pos);
        }
    
        if(uCharacter=='3'){
            changeState(U4DEngine::macKey3, uInputAction, pos);
        }
    
        if(uCharacter=='4'){
            changeState(U4DEngine::macKey4, uInputAction, pos);
        }
    
        if(uCharacter==' '){
            changeState(U4DEngine::macSpaceKey, uInputAction, pos);
        }

    }
    
    
}
