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

GameLogic::GameLogic():pAgent(nullptr){
    
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    //1. Get a pointer to the Earth object
    Earth *pEarth=dynamic_cast<Earth*>(getGameWorld());
    
    //2. Search for the Astronaut object
    pAgent=dynamic_cast<Agent*>(pEarth->searchChild("agent0"));
    
}


void GameLogic::receiveUserInputUpdate(void *uData){
    
    //1. Get the user-input message from the structure
    
    ControllerInputMessage controllerInputMessage=*(ControllerInputMessage*)uData;
    
    //check the astronaut model exists
    if(pAgent!=nullptr){
        
        //2. Determine what was pressed, buttons, keys or joystick
        
        switch (controllerInputMessage.controllerInputType) {
                
            
                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case actionButtonA:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //4a. What action to take if button was pressed
                    
                    mouseMovementDirection=leftDir;
                    
                    if(pAgent->getState()!=walking){
                        pAgent->changeState(walking);
                        
                    }
                    
                    for(const auto &n:pAgent->neighbors){
                        
                        if(n!=pAgent){
                            U4DEngine::U4DVector3n pos=pAgent->getAbsolutePosition();
                            n->setTargetPosition(pos);
                            n->changeState(flocking);
                        }
                        
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if(pAgent->getState()!=idle && mouseMovementDirection==leftDir){
                        pAgent->changeState(idle);
                        
                        for(const auto &n:pAgent->neighbors){
                            
                            if(n!=pAgent){
                                n->changeState(idle);
                            }
                            
                        }
                        
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
                    
                    if(pAgent->getState()!=walking){
                        pAgent->changeState(walking);
                    }
                    
                    for(const auto &n:pAgent->neighbors){
                        
                        if(n!=pAgent){
                            U4DEngine::U4DVector3n pos=pAgent->getAbsolutePosition();
                            n->setTargetPosition(pos);
                            n->changeState(flocking);
                        }
                        
                    }
                    
                    //8. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if(pAgent->getState()!=idle && mouseMovementDirection==rightDir){
                        pAgent->changeState(idle);
                        for(const auto &n:pAgent->neighbors){
                            
                            if(n!=pAgent){
                                n->changeState(idle);
                            }
                            
                        }
                    }
                }
                
            }
                
                break;
                
            case actionButtonW:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    mouseMovementDirection=forwardDir;
                    if(pAgent->getState()!=walking){
                        pAgent->changeState(walking);
                        
                    }
                    
                    for(const auto &n:pAgent->neighbors){
                        
                        if(n!=pAgent){
                            U4DEngine::U4DVector3n pos=pAgent->getAbsolutePosition();
                            n->setTargetPosition(pos);
                            n->changeState(flocking);
                        }
                        
                    }
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if(pAgent->getState()!=idle && mouseMovementDirection==forwardDir){
                        pAgent->changeState(idle);
                        for(const auto &n:pAgent->neighbors){
                            
                            if(n!=pAgent){
                                n->changeState(idle);
                            }
                            
                        }
                    }
                }
            }
                break;
                
            case actionButtonS:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //step 5. Change the state to walk if joystick is moved. Idle otherwise
                    
                    mouseMovementDirection=backwardDir;
                    
                    if(pAgent->getState()!=walking){
                        pAgent->changeState(walking);
                    }
                    
                    for(const auto &n:pAgent->neighbors){
                        
                        if(n!=pAgent){
                            U4DEngine::U4DVector3n pos=pAgent->getAbsolutePosition();
                            n->setTargetPosition(pos);
                            n->changeState(flocking);
                        }
                        
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    if(pAgent->getState()!=idle && mouseMovementDirection==backwardDir){
                        pAgent->changeState(idle);
                        for(const auto &n:pAgent->neighbors){
                            
                            if(n!=pAgent){
                                n->changeState(idle);
                            }
                            
                        }
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
                
                //10. mouse was moved

                if (controllerInputMessage.controllerInputData==mouseActive) {
                
                //SNIPPET TO USE FOR MOUSE ABSOLUTE POSITION
                U4DEngine::U4DVector3n p1=controllerInputMessage.mousePosition;
                U4DEngine::U4DVector3n p2=controllerInputMessage.previousMousePosition;


                float p1z=1.0-(p1.x*p1.x+p1.y*p1.y);
                p1.z=p1z>0.0 ? std::sqrt(p1z) :0.0;

                float p2z=1.0-(p2.x*p2.x+p2.y*p2.y);
                p2.z=p2z>0.0 ? std::sqrt(p2z) :0.0;


                U4DEngine::U4DVector3n axis;

                U4DEngine::U4DVector3n mouseDirection=p1-p2;

                mouseDirection.normalize();

                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                U4DEngine::U4DVector3n xVector(1.0,0.0,0.0);

                //get the dot product
                float upDot, xDot;

                upDot=mouseDirection.dot(upVector);
                xDot=mouseDirection.dot(xVector);

                U4DEngine::U4DVector3n v=pAgent->getViewInDirection();
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

                            axis=upVector*-1.0;

                        }else{

                            axis=upVector;
                        }

                    }

                    float angle=p1.angle(p2);

                    float biasAngleAccumulator=0.90;

                    angleAccumulator=angleAccumulator*biasAngleAccumulator+angle*(1.0-biasAngleAccumulator);

                    U4DEngine::U4DQuaternion newOrientation(angleAccumulator,axis);

                    U4DEngine::U4DQuaternion modelOrientation=pAgent->getAbsoluteSpaceOrientation();

                    U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation,1.0);

                    pAgent->rotateBy(p);

                }
                    
                    
                }else if(controllerInputMessage.controllerInputData==mouseInactive){
                    
                    
                }
                
            }
                
            default:
                break;
        }
        
            //step 4. Set the force direction
            U4DEngine::U4DVector3n forceDir=pAgent->getViewInDirection();

            forceDir.y=0.0;

            forceDir.normalize();

            if(mouseMovementDirection==forwardDir){

                pAgent->setForceDirection(forceDir);

            }else if(mouseMovementDirection==backwardDir){

                //go backwards
                forceDir*=-1.0;

                pAgent->setForceDirection(forceDir);

            }else if(mouseMovementDirection==leftDir){
                //go left
                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                forceDir=forceDir.cross(upVector);

                pAgent->setForceDirection(forceDir);

            }else if(mouseMovementDirection==rightDir){

                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                forceDir=upVector.cross(forceDir);

                pAgent->setForceDirection(forceDir);

        }
        
    }
    
}
