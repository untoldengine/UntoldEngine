//
//  DemoLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "DemoLogic.h"
#include "U4DDirector.h"
#include "CommonProtocols.h"
#include "DemoWorld.h"
#include "U4DDebugger.h"
#include "U4DCamera.h"

DemoLogic::DemoLogic():motionAccumulator(0.0,0.0,0.0),angleAccumulator(0.0),pPlayer(nullptr),navigation(nullptr){
    
    //create the callback
    navigationScheduler=new U4DEngine::U4DCallback<DemoLogic>;
    
    //create the timer
    navigationTimer=new U4DEngine::U4DTimer(navigationScheduler);
    
}

DemoLogic::~DemoLogic(){
    
    //In the class destructor, make sure to delete the callback and timer as follows
        
    navigationScheduler->unScheduleTimer(navigationTimer);
    
    delete navigationScheduler;
    
    delete navigationTimer;
}

void DemoLogic::update(double dt){
    
    
}

void DemoLogic::init(){
    
    //create the navigation object. The navigation object computes the best path to target by using the A* algorithm
    navigation=new U4DEngine::U4DNavigation();
    
    //2. Load a Navigation Mesh by providing the name of the nav mesh and the file
    if(navigation->loadNavMesh("Navmesh","navMesh.u4d")){
        //set options here such as path radius
    }
    
    //Get the pointers to the hero and enemies soldiers
    
    //1. Get a pointer to the LevelOneWorld object
    DemoWorld *pEarth=dynamic_cast<DemoWorld*>(getGameWorld());
    
    //2. Search for the player object
    pPlayer=dynamic_cast<Hero*>(pEarth->searchChild("hero"));
    
    //search for all enemies
    for(int i=0;i<sizeof(pEnemies)/sizeof(pEnemies[0]);i++){
    
        std::string name="germansoldier";
        name+=std::to_string(i);
        
        pEnemies[i]=dynamic_cast<Enemy*>(pEarth->searchChild(name));
        
    }
    
    //scheduele the navigation path to be computed every 3secs. The information will be passed to the enemy soldiers
    navigationScheduler->scheduleClassWithMethodAndDelay(this, &DemoLogic::computeNavigation, navigationTimer, 3.0,true);
    
}

void DemoLogic::computeNavigation(){
    
    //Target position is the hero soldier position
    U4DEngine::U4DVector3n targetPosition=pPlayer->getAbsolutePosition();

    for(int i=0;i<sizeof(pEnemies)/sizeof(pEnemies[0]);i++){
     
        navigation->computePath(pEnemies[i],targetPosition);

        //4. Compute the final "Navigation" velocity for the character
        U4DEngine::U4DVector3n navigationVelocity=navigation->getSteering(pEnemies[i]);

        //Set the final velocity y component to zero.
        navigationVelocity.y=0.0;
        
        pEnemies[i]->setNavigationVelocity(navigationVelocity);
        
    }
    
}

void DemoLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
    
    if (pPlayer!=nullptr) {
        
        switch (controllerInputMessage.inputElementType) {
            
            case U4DEngine::uiButton:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                        
                        //std::cout<<"Button A pressed"<<std::endl;
                    
                    
                    }
                    
                }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){
                
                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                        
                        //std::cout<<"Button A released"<<std::endl;
                    
                    
                    }
                
                }
                
                break;
                
            case U4DEngine::uiSlider:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiSliderMoved){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("sliderA")==0) {
                        
                        
                    
                    }else if(controllerInputMessage.elementUIName.compare("sliderB")==0){
                        
                        
                        
                    }
                    
                }
                
                break;
            
            case U4DEngine::uiJoystick:
            
            if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){
                
                
                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
                    
                    
                
                }
                
            }else if (controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){
            
                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
                    
                    //std::cout<<"joystick released"<<std::endl;
                
                
                }
            
            }
            
            break;
                
            case U4DEngine::uiCheckbox:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiCheckboxPressed){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("checkboxA")==0) {
                        
                        
                    
                    }else if(controllerInputMessage.elementUIName.compare("checkboxB")==0){
                     
                        
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
                    
                    //std::cout<<"left released"<<std::endl;
                    
                }
            }
                
                break;

                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case U4DEngine::macKeyA:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    mouseMovementDirection=leftDir;
                                        
                    if(pPlayer->getState()!=stealth){
                        pPlayer->changeState(stealth);
                        
                    }
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if(pPlayer->getState()!=idle && mouseMovementDirection==leftDir){
                        pPlayer->changeState(idle);
                    }
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case U4DEngine::macKeyD:
            {
                //7. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    mouseMovementDirection=rightDir;
                                        
                    if(pPlayer->getState()!=stealth){
                        pPlayer->changeState(stealth);
                    }
                    
                    
                    //8. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if(pPlayer->getState()!=idle && mouseMovementDirection==rightDir){
                        pPlayer->changeState(idle);
                    }

                }
                
            }
                
                break;
                
            case U4DEngine::macKeyW:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    mouseMovementDirection=forwardDir;
                    if(pPlayer->getState()!=stealth){
                        pPlayer->changeState(stealth);
                        
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if(pPlayer->getState()!=idle && mouseMovementDirection==forwardDir){
                        pPlayer->changeState(idle);
                    }
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    mouseMovementDirection=backwardDir;
                                        
                    if(pPlayer->getState()!=stealth){
                        pPlayer->changeState(stealth);
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    if(pPlayer->getState()!=idle && mouseMovementDirection==backwardDir){
                    
                        pPlayer->changeState(idle);
                                            
                    }
                    
                }
                
            }
                break;
                
                
            case U4DEngine::macShiftKey:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    //CODE SNIPPET to reload shaders. Make sure the path is correct
//                    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
//
//                    debugger->reloadShader("minimappipeline", "/path_to_your_shader/minimapHotReloadShader.metal", "vertexMinimapShader", "fragmentMinimapShader");
                }
                
            }
                break;
                
            case U4DEngine::padButtonA:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                     
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padButtonB:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padRightTrigger:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padLeftTrigger:
            
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                    
                }
            
            break;
                
            case U4DEngine::padLeftThumbstick:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
                                   
                   //Get joystick direction
                   U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,0.0,controllerInputMessage.joystickDirection.y);
                   
                    joystickDirection.normalize();
                    U4DEngine::U4DVector3n v=pPlayer->getViewInDirection();
                    v.normalize();
                    pPlayer->setForceDirection(v);
                    
                    if(pPlayer->getState()!=stealth){
                        pPlayer->changeState(stealth);
                    }
                    
               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                   
                   if(pPlayer->getState()!=idle){
                   
                       pPlayer->changeState(idle);
                                           
                   }

               }
            
            break;
                
            case U4DEngine::padRightThumbstick:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
                                   
                   //Get joystick direction
                   U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,controllerInputMessage.joystickDirection.y,0.0);
                    
                    //The following snippet will determine which way to rotate the model depending on the motion of the thumbstick
                    float joystickMovMagnitude=joystickDirection.magnitude();
                    
                    joystickDirection.normalize();
                    
                    U4DEngine::U4DVector3n axis;
                    
                    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                    U4DEngine::U4DVector3n xVector(1.0,0.0,0.0);
                    
                    //get the dot product
                    float upDot, xDot;
                    
                    upDot=joystickDirection.dot(upVector);
                    xDot=joystickDirection.dot(xVector);
                    
                    U4DEngine::U4DVector3n v=pPlayer->getViewInDirection();
                    v.normalize();
                    
                    
                        //if direction is closest to upvector
                        if(std::abs(upDot)>=std::abs(xDot)){
                            //rotate about x axis
                            
//                            if(upDot>0.0){
//
//                                axis=v.cross(upVector);
//
//                            }else{
//                                axis=v.cross(upVector)*-1.0;
//
//                            }
                        }else{
                            
                            //rotate about y axis
                            if(xDot>0.0){

                                axis=upVector;

                            }else{

                                axis=upVector*-1.0;
                            }
                            
                        }
                    
                    
                        //Rotate the object according to the motion of the thumbstick
                        float angle=1.0*joystickMovMagnitude;
                        
                        float biasAngleAccumulator=0.90;
                        
                        angleAccumulator=angleAccumulator*biasAngleAccumulator+angle*(1.0-biasAngleAccumulator);
                        
                        U4DEngine::U4DQuaternion newOrientation(angleAccumulator,axis);
                        
                        U4DEngine::U4DQuaternion modelOrientation=pPlayer->getAbsoluteSpaceOrientation();
                        
                        U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation,1.0);
                        
                        pPlayer->rotateBy(p);
                    
               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                   
                   
                   
                   
               }
            
            break;
                
            case U4DEngine::mouse:
            {
                
                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
                
                    //SNIPPET TO USE FOR MOUSE ABSOLUTE POSITION
                    
                    //USE THIS SNIPPET WHEN YOU ONLY WANT THE MOUSE DELTA LOCATION
                    U4DEngine::U4DVector2n delta=controllerInputMessage.mouseDeltaPosition;
                    //the y delta should be flipped
                    delta.y*=-1.0;
                    
                    //The following snippet will determine which way to rotate the model depending on the motion of the mouse
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

//                            if(upDot>0.0){
//                                axis=v.cross(upVector);
//
//                            }else{
//                                axis=v.cross(upVector)*-1.0;
//
//                            }
                        }else{

                            //rotate about y axis
                            if(xDot>0.0){

                                axis=upVector;

                            }else{

                                axis=upVector*-1.0;
                            }

                        }

                        //Rotate the object according to the motion of the mouse
                        
                        float angle=0.03*deltaMagnitude;
                        
                        float biasAngleAccumulator=0.90;

                        angleAccumulator=angleAccumulator*biasAngleAccumulator+angle*(1.0-biasAngleAccumulator);
                        
                        U4DEngine::U4DQuaternion newOrientation(angleAccumulator,axis);

                        U4DEngine::U4DQuaternion modelOrientation=pPlayer->getAbsoluteSpaceOrientation();

                        U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation,1.0);

                        pPlayer->rotateBy(p);
                            
                    }

                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
                    
                    //std::cout<<"Mouse stopped"<<std::endl;
                }
                
            }
                
                break;
                
                
            default:
                break;
        }
    
        //step 4. Set the force direction
        U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();

        forceDir.y=0.0;

        forceDir.normalize();


        if(mouseMovementDirection==forwardDir){

            pPlayer->setForceDirection(forceDir);

        }else if(mouseMovementDirection==backwardDir){

            //go backwards
            forceDir*=-1.0;

            pPlayer->setForceDirection(forceDir);

        }else if(mouseMovementDirection==leftDir){
            //go left
            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            forceDir=forceDir.cross(upVector);

            pPlayer->setForceDirection(forceDir);

        }else if(mouseMovementDirection==rightDir){

            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            forceDir=upVector.cross(forceDir);

            pPlayer->setForceDirection(forceDir);


        }
    
    }
    
} 
