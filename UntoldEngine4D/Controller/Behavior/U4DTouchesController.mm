//
//  U4DTouchesController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DTouchesController.h"
#include "U4DGameModelInterface.h"
#include "U4DVector2n.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "U4DWorld.h"

namespace U4DEngine {
    
    
void U4DTouchesController::setGameWorld(U4DWorld *uGameWorld){
    
    gameWorld=uGameWorld;

}


void U4DTouchesController::setGameModel(U4DGameModelInterface *uGameModel){
    
    gameModel=uGameModel;

}
    
U4DWorld* U4DTouchesController::getGameWorld(){

    return gameWorld;
}

U4DGameModelInterface* U4DTouchesController::getGameModel(){
    
    return gameModel;
}
    
    
void U4DTouchesController::touchBegan(const U4DTouches &touches){
    
    changeState(touches, rTouchesBegan);
}

void U4DTouchesController::touchMoved(const U4DTouches &touches){
 
    changeState(touches, rTouchesMoved);
    
}

void U4DTouchesController::touchEnded(const U4DTouches &touches){
    
    changeState(touches, rTouchesEnded);
}


void U4DTouchesController::add(U4DButton *uButton){
    
    buttonsArray.push_back(uButton);
    
}

void U4DTouchesController::add(U4DJoyStick *uJoyStick){
    
    joyStickArray.push_back(uJoyStick);
    
}

void U4DTouchesController::changeState(const U4DTouches &touches,TOUCHSTATE touchState){
    
    //button
    std::vector<U4DButton*>::iterator buttonPos;
    U4DVector3n touchPosition(touches.xTouch,touches.yTouch,0.0);
    
    for(buttonPos=buttonsArray.begin();buttonPos !=buttonsArray.end();++buttonPos){
        
        U4DButton *button=*buttonPos;

        button->changeState(touchState,touchPosition);
        
    }
    
    
    
    //joystick
    std::vector<U4DJoyStick*>::iterator joyStickPos;
    
    for(joyStickPos=joyStickArray.begin();joyStickPos !=joyStickArray.end();++joyStickPos){
        
        U4DJoyStick *joyStick=*joyStickPos;
        
        joyStick->changeState(touchState, touchPosition);
    
    }
    
    
}

void U4DTouchesController::update(float dt){
    
    std::vector<U4DButton*>::iterator buttonPos;
    
    for(buttonPos=buttonsArray.begin();buttonPos !=buttonsArray.end();++buttonPos){
        
        U4DButton *button=*buttonPos;
        
        button->update(dt);
    }
    
    std::vector<U4DJoyStick*>::iterator joyStickPos;
    
    for(joyStickPos=joyStickArray.begin();joyStickPos !=joyStickArray.end();++joyStickPos){
        
        U4DJoyStick *joyStick=*joyStickPos;
        
        joyStick->update(dt);
    }
    
    if (receivedAction==true) {
        
        sendTouchUpdateToModel();
        
        receivedAction=false;
    }
}

void U4DTouchesController::draw(){
    
    std::vector<U4DButton*>::iterator buttonPos;
    
    for(buttonPos=buttonsArray.begin();buttonPos !=buttonsArray.end();++buttonPos){
        
        U4DButton *button=*buttonPos;
        
        button->draw();
        
    }
    
    
    std::vector<U4DJoyStick*>::iterator joyStickPos;
    
    for(joyStickPos=joyStickArray.begin();joyStickPos !=joyStickArray.end();++joyStickPos){
        
        U4DJoyStick *joyStick=*joyStickPos;
        
        joyStick->draw();
        
    }
    
}

U4DVector3n U4DTouchesController::getJoyStickData(std::string uName){
    
    U4DVector3n joyStickData;
    
    std::vector<U4DJoyStick*>::iterator joyStickPos;
    
    for(joyStickPos=joyStickArray.begin();joyStickPos !=joyStickArray.end();++joyStickPos){
        
        U4DJoyStick *joyStick=*joyStickPos;
        
        if (joyStick->getName().compare(uName)==0) {
            
            joyStickData=joyStick->getDataPosition();
            
            break;
        }
    }
    
    return joyStickData;
}
    
void U4DTouchesController::sendTouchUpdateToModel(){

    gameModel->receiveTouchUpdate();
}
    
void U4DTouchesController::setReceivedAction(bool uValue){

    receivedAction=uValue;
}

}