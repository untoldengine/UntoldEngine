//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "GameLogic.h"
#include "Earth.h"

using namespace U4DEngine;

GameLogic::GameLogic():pPlayer(nullptr){
    
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    //1. Get a pointer to the Earth object
    Earth *pEarth=dynamic_cast<Earth*>(getGameWorld());
    
    //2. Search for the Astronaut object
    pPlayer=dynamic_cast<Player*>(pEarth->searchChild("player"));
    
}


void GameLogic::receiveUserInputUpdate(void *uData){
    
    //1. Get the user-input message from the structure
    
    ControllerInputMessage controllerInputMessage=*(ControllerInputMessage*)uData;
    
    //check the astronaut model exists
    if(pPlayer!=nullptr){
        
        //2. Determine what was pressed, buttons, keys or joystick
        
        switch (controllerInputMessage.controllerInputType) {
                
            case actionMouseLeftTrigger:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    if(pPlayer->getState()!=shooting){
                        pPlayer->changeState(shooting);
                    }
                        
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    
                    if(pPlayer->getState()!=pPlayer->getPreviousState()){
                        
                        pPlayer->changeState(pPlayer->getPreviousState());
                   }
                    
                }
            }
                
                break;

                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case actionButtonA:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //4a. What action to take if button was pressed
                    mouseMovementDirection=leftDir;
                    
                    if(pPlayer->getState()!=patrol){
                        pPlayer->changeState(patrol);
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==leftDir) {
                        pPlayer->changeState(patrolidle);
                    }
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case actionButtonD:
            {
                //7. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //7a. What action to take if button was pressed
                    mouseMovementDirection=rightDir;
                    
                    if(pPlayer->getState()!=patrol){
                        pPlayer->changeState(patrol);
                    }
                    
                    //8. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==rightDir) {
                        pPlayer->changeState(patrolidle);
                    }

                }
                
            }
                
                break;
                
            case actionButtonW:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //5a. what action to take if button was pressed
                    mouseMovementDirection=forwardDir;
                    
                    if (pPlayer->getState()!=patrol) {
                        pPlayer->changeState(patrol);
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==forwardDir) {
                        pPlayer->changeState(patrolidle);
                    }
                    
                }
            }
                break;
                
            case actionButtonS:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //5a. what action to take if button was pressed
                    mouseMovementDirection=backwardDir;
                    
                    if (pPlayer->getState()!=patrol) {
                        pPlayer->changeState(patrol);
                    }
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==backwardDir) {
                        pPlayer->changeState(patrolidle);
                        
                    }
                    
                }
                
            }
                break;
                
                //9. Did joystic on a mobile or game controller receive an action from the user. (Arrow keys and Mouse on Mac)
            case actionJoystick:
            {
                //10. Joystick was moved
                
                if (controllerInputMessage.controllerInputData==joystickActive) {
                    
                    //11. Get joystick movement
                    JoystickMessageData joystickMessageData;
                    
                    //11a. Get Joystick direction
                    joystickMessageData.direction=controllerInputMessage.joystickDirection;
                    
                    //12. What action to take when joystick is moved.
                    std::cout<<"Joystick moved"<<std::endl;
                    
                    
                }else if(controllerInputMessage.controllerInputData==joystickInactive){
                    
                    
                }
                
            }
                
                break;
                
            case actionMouse:
            {
                
                //USE THIS SNIPPET WHEN YOU ONLY WANT THE MOUSE DELTA LOCATION
                U4DEngine::U4DVector2n delta=controllerInputMessage.mouseDeltaPosition;
                //set y to zero
                delta.y=0.0;
                float deltaMagnitude=delta.magnitude();
                delta.normalize();

                U4DEngine::U4DVector3n axis;

                U4DEngine::U4DVector3n mouseDirection(delta.x,delta.y,0.0);
                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                U4DEngine::U4DVector3n xVector(1.0,0.0,0.0);

                //get the dot product
                float upDot, xDot;

                upDot=mouseDirection.dot(upVector);
                xDot=mouseDirection.dot(xVector);

                U4DEngine::U4DVector3n v=pPlayer->getViewInDirection();
                v.normalize();

                if(mouseDirection.magnitude()>0){
                    //if direction is closest to upvector
                    if(std::abs(upDot)>=std::abs(xDot)){
                        //rotate about x axis

                        if(upDot>0.0){
                            axis=v.cross(upVector);

                        }else{
                            axis=v.cross(upVector)*-1.0;

                        }
                    }else{

                        //rotate about y axis
                        if(xDot>0.0){

                            axis=upVector;

                        }else{

                            axis=upVector*-1.0;
                        }

                    }

                    float angle=0.03*deltaMagnitude;

                    float biasAngleAccumulator=0.20;

                    angleAccumulator=angleAccumulator*biasAngleAccumulator+angle*(1.0-biasAngleAccumulator);

                    U4DEngine::U4DQuaternion newOrientation(angleAccumulator,axis);

                    U4DEngine::U4DQuaternion modelOrientation=pPlayer->getAbsoluteSpaceOrientation();

                    U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation,1.0);

                    pPlayer->rotateBy(p);
    
                    
                }else if(controllerInputMessage.controllerInputData==mouseInactive){
                    
                    
                }
                
            }
                
            default:
                break;
        }
        
        //set the force direction
        U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();
        
        forceDir.y=0.0;
        
        forceDir.normalize();
        
        if (mouseMovementDirection==forwardDir) {
         
            pPlayer->setForceDirection(forceDir);
        
        }else if (mouseMovementDirection==backwardDir){
            
            //go backwards. reverse direction
            forceDir*=-1.0;
            
            pPlayer->setForceDirection(forceDir);
        
        }else if (mouseMovementDirection==leftDir){
            
            //go left
            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            forceDir=forceDir.cross(upVector);
            
            pPlayer->setForceDirection(forceDir);
            
        }else if (mouseMovementDirection==rightDir){
            
            //go right
            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            forceDir=upVector.cross(forceDir);
            
            pPlayer->setForceDirection(forceDir);
            
        }
        
        
    }
    
}
