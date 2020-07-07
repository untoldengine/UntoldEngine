//
//  LevelOneLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "LevelOneLogic.h"
#include "LevelOneWorld.h"
#include "CommonProtocols.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "StartScene.h"

using namespace U4DEngine;

LevelOneLogic::LevelOneLogic():pPlayer(nullptr){
    
    
}

LevelOneLogic::~LevelOneLogic(){
    
   
}

void LevelOneLogic::update(double dt){
    
}

void LevelOneLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
    LevelOneWorld *pEarth=dynamic_cast<LevelOneWorld*>(getGameWorld());
    
    //2. Search for the Astronaut object
    pPlayer=dynamic_cast<Player*>(pEarth->searchChild("astronaut0"));
    
}


void LevelOneLogic::receiveUserInputUpdate(void *uData){
    
    //1. Get the user-input message from the structure
    
    CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
    
    
    //check the astronaut model exists
    if(pPlayer!=nullptr){
        
        //2. Determine what was pressed, buttons, keys or joystick
        
        switch (controllerInputMessage.inputElementType) {
            
            case U4DEngine::ioTouch:
            {
                mouseMovementDirection=noDir;
                
                if (controllerInputMessage.elementUIName.compare("buttonA")!=0 && controllerInputMessage.elementUIName.compare("buttonB")!=0 && controllerInputMessage.elementUIName.compare("joystick")!=0 ) {
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::ioTouchesBegan){

                        if(pPlayer->getState()!=shooting){

                            pPlayer->changeState(shooting);
                        }

                    }else if(controllerInputMessage.inputElementAction==U4DEngine::ioTouchesEnded){

                        if(pPlayer->getState()!=pPlayer->getPreviousState()){

                             pPlayer->changeState(pPlayer->getPreviousState());
                        }

                    }
                    
                }
                

            }
                break;
            case U4DEngine::mouseLeftButton:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::mouseButtonPressed) {
                    
                    if(pPlayer->getState()!=shooting){
                        pPlayer->changeState(shooting);
                    }
                        
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseButtonReleased){
                    
                    
//                    if(pPlayer->getState()!=pPlayer->getPreviousState()){
//
//                        pPlayer->changeState(pPlayer->getPreviousState());
//                   }
                    
                }
            }
                
                break;

                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case U4DEngine::macKeyA:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    //4a. What action to take if button was pressed
                    mouseMovementDirection=leftDir;
                    
                    if(pPlayer->getState()!=patrol){
                        pPlayer->changeState(patrol);
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==leftDir) {
                        pPlayer->changeState(patrolidle);
                    }
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case U4DEngine::macKeyD:
            {
                //7. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    //7a. What action to take if button was pressed
                    mouseMovementDirection=rightDir;
                    
                    if(pPlayer->getState()!=patrol){
                        pPlayer->changeState(patrol);
                    }
                    
                    //8. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==rightDir) {
                        pPlayer->changeState(patrolidle);
                    }

                }
                
            }
                
                break;
                
            case U4DEngine::macKeyW:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    //5a. what action to take if button was pressed
                    mouseMovementDirection=forwardDir;

                    if (pPlayer->getState()!=patrol) {
                        pPlayer->changeState(patrol);
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==forwardDir) {
                        pPlayer->changeState(patrolidle);
                    }
                    
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    //5a. what action to take if button was pressed
                    mouseMovementDirection=backwardDir;
                    
                    if (pPlayer->getState()!=patrol) {
                        pPlayer->changeState(patrol);
                    }
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if (pPlayer->getState()!=patrolidle && mouseMovementDirection==backwardDir) {
                        pPlayer->changeState(patrolidle);
                        
                    }
                    
                }
                
            }
                break;
                
            case U4DEngine::mouse:
            {
                
                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
                    
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

                }
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
                    
                    
                }
                
            }
                
                break;
                
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
