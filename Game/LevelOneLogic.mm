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
#include "Ball.h"

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
    pPlayer=dynamic_cast<Player*>(pEarth->searchChild("player0"));
    
}

void LevelOneLogic::setActivePlayer(Player *uActivePlayer){
    
    pPlayer=uActivePlayer;
    
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

                        

                    }else if(controllerInputMessage.inputElementAction==U4DEngine::ioTouchesEnded){



                    }
                    
                }
                

            }
                break;
            case U4DEngine::mouseLeftButton:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::mouseButtonPressed) {
                    
                    
                        
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseButtonReleased){
                    
                    
                    
                }
            }
                
                break;

                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case U4DEngine::macKeyA:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case U4DEngine::macKeyD:
            {
                //7. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    
                    //8. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    

                }
                
            }
                
                break;
                
            case U4DEngine::macKeyW:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                   
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                   
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
                }
                
            }
                break;
                
            case U4DEngine::padButtonA:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    pPlayer->setEnablePassing(true);
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padLeftThumbstick:
            
                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
                    
                    //Get joystick direction
                    U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,0.0,controllerInputMessage.joystickDirection.y);
                    
                    //Get entity forward vector for the player
                    U4DEngine::U4DVector3n v=pPlayer->getViewInDirection();
                    
                    v.normalize();
                    
                    //set an up-vector
                    U4DVector3n upVector(0.0,1.0,0.0);
                    
                    U4DMatrix3n m=pPlayer->getAbsoluteMatrixOrientation();
                    
                    //transform the up vector
                    upVector=m*upVector;
                    
                    U4DEngine::U4DVector3n posDir=v.cross(upVector);
                    
                    //Get the angle between the analog joystick direction and the view direction
                    float angle=v.angle(joystickDirection);
                    
                    //if the dot product between the joystick-direction and the positive direction is less than zero, flip the angle
                    if(joystickDirection.dot(posDir)>0.0){
                        angle*=-1.0;
                    }
                    
                    //create a quaternion between the angle and the upvector
                    U4DEngine::U4DQuaternion newOrientation(angle,upVector);
                    
                    //Get current orientation of the player
                    U4DEngine::U4DQuaternion modelOrientation=pPlayer->getAbsoluteSpaceOrientation();
                    
                    //create slerp interpolation
                    U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation, 1.0);
                    
                    //rotate the character
                    pPlayer->rotateBy(p);
                    
                    //set the force direction
                    U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();
            
                    forceDir.y=0.0;
            
                    forceDir.normalize();
            
                    pPlayer->setForceDirection(forceDir);
                    
                    pPlayer->setEnableDribbling(true);
                    
                    pPlayer->setDribblingDirection(joystickDirection);
                    
                }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                    
                    pPlayer->setEnableDribbling(false);
                    
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
        
//        //set the force direction
//        U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();
//
//        forceDir.y=0.0;
//
//        forceDir.normalize();
//
//        if (mouseMovementDirection==forwardDir) {
//
//            pPlayer->setForceDirection(forceDir);
//
//        }else if (mouseMovementDirection==backwardDir){
//
//            //go backwards. reverse direction
//            forceDir*=-1.0;
//
//            pPlayer->setForceDirection(forceDir);
//
//        }else if (mouseMovementDirection==leftDir){
//
//            //go left
//            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
//            forceDir=forceDir.cross(upVector);
//
//            pPlayer->setForceDirection(forceDir);
//
//        }else if (mouseMovementDirection==rightDir){
//
//            //go right
//            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
//            forceDir=upVector.cross(forceDir);
//
//            pPlayer->setForceDirection(forceDir);
//
//        }
        
        
    }
    
}
