//
//  U4DSceneManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneManager.h"
#include "U4DDirector.h"
#include "U4DTouchesController.h"
#include "U4DGamepadController.h"
#include "U4DKeyboardController.h"
#include "U4DResourceLoader.h"
#include "U4DLayerManager.h"
#include "U4DScheduler.h"
#include "U4DCamera.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneActiveState.h"
#include "U4DSceneIdleState.h"
#include "CommonProtocols.h"
#include "U4DProfilerManager.h"

namespace U4DEngine {

    U4DSceneManager* U4DSceneManager::instance=0;

    U4DSceneManager::U4DSceneManager():currentScene(nullptr),controllerInput(nullptr),requestToChangeScene(false){
        
        //get instance of director
        U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        //get device type
        if(director->getDeviceOSType()==U4DEngine::deviceOSIOS){
            
            controllerInput=new U4DTouchesController();
            
        }else if(director->getDeviceOSType()==U4DEngine::deviceOSMACX){
            
            if(director->getGamePadControllerPresent()){
                
                //Game controller detected
                controllerInput=new U4DGamepadController();
                
            }else{
                
                //enable keyboard control
                controllerInput=new U4DKeyboardController();
                
            }
            
        }
        
        if (controllerInput!=nullptr) {
            controllerInput->init();
        }
        
        profilerScheduler=new U4DCallback<U4DSceneManager>;
        
        profilerTimer=new U4DTimer(profilerScheduler);
        
    }
        
    U4DSceneManager::~U4DSceneManager(){
        
        //unsubscribe the timer
        profilerScheduler->unScheduleTimer(profilerTimer);
        
        delete profilerScheduler;
        delete profilerTimer;
        
    }
        
    U4DSceneManager* U4DSceneManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DSceneManager();
            
        }
        
        return instance;
    }

    void U4DSceneManager::changeScene(U4DScene *uScene){
        
        //if scene already exists
        if (currentScene!=nullptr) {
            
            requestToChangeScene=true;
            
            sceneToChange=uScene;
            
        }else{
            
            //If no scene exist, then, go ahead and initialize the scene
            
            currentScene=uScene;
            
            uScene->init();
            
        }
        
    }

    void U4DSceneManager::isSafeToChangeScene(){
        
       //check if current scene is not a nullpointer
       if (currentScene!=nullptr) {
           
           U4DSceneStateManager *sceneStateManager=currentScene->getSceneStateManager();
           
           //If there was a request to change scene, make sure it is safe to change
           if (sceneStateManager->getCurrentState()==U4DSceneActiveState::sharedInstance()) {
               
               sceneStateManager->changeState(U4DSceneIdleState::sharedInstance());
               
               requestToChangeScene=false;
               
               //delete curren scene
               delete currentScene;
               
               currentScene=nullptr;
               
               //init the new scene
               sceneToChange->init();
               
               //set the current scene to the new scene
               currentScene=sceneToChange;
               
           }

       }
       
        
    }

    U4DScene *U4DSceneManager::getCurrentScene(){
        
        return currentScene;
        
    }

    U4DControllerInterface *U4DSceneManager::getGameController(){
        
        return controllerInput;
    
    }

    void U4DSceneManager::setRequestToChangeScene(bool uValue){
        requestToChangeScene=uValue;
    }

    bool U4DSceneManager::getRequestToChangeScene(){
            
        return requestToChangeScene;
        
    }

    void U4DSceneManager::enableSceneProfiling(){
        
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        
        profilerManager->setEnableProfiler(true);

       profilerScheduler->scheduleClassWithMethodAndDelay(this, &U4DSceneManager::captureProfilerData, profilerTimer,1.0, true);
        
    }

    void U4DSceneManager::disableSceneProfiling(){
        
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        
        profilerManager->setEnableProfiler(false);
        
        //unsubscribe the timer
        profilerScheduler->unScheduleTimer(profilerTimer);
        
    }

    void U4DSceneManager::captureProfilerData(){
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        
        profilerData=profilerManager->getProfileLog();
    }
    
}
