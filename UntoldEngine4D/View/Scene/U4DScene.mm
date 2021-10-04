//
//  U4DScene.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DDirector.h"
#include "U4DScheduler.h"
#include "Constants.h"
#include "U4DSceneManager.h"
#include "U4DSceneStateManager.h"
#include "U4DScene.h"
#include "U4DSceneActiveState.h"
#include "U4DSceneIdleState.h"
#include "U4DSceneLoadingState.h"
#include "U4DSceneEditingState.h"
#include "U4DLogger.h"
#include <thread>

namespace U4DEngine {
    
    //constructor
    U4DScene::U4DScene():sceneStateManager(nullptr),accumulator(0.0),globalTime(0.0),componentsMultithreadLoaded(false),anchorMouse(false),pauseScene(true){

        sceneStateManager=new U4DSceneStateManager(this);
        
    };

    //destructor
    U4DScene::~U4DScene(){

        delete sceneStateManager;
        
    };

    void U4DScene::loadComponents(U4DWorld *uGameWorld, U4DGameLogicInterface *uGameLogic){
        
        if (uGameWorld!=nullptr  && uGameLogic!=nullptr) {
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            gameWorld=uGameWorld;
            gameController=sceneManager->getGameController();
            gameLogic=uGameLogic;
            
            sceneStateManager->changeState(U4DSceneActiveState::sharedInstance());
            
        }else{
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("The Game World or the the Game Model (logic) are nullptr");
        }
        
    
    }

    void U4DScene::loadComponents(U4DWorld *uGameWorld, U4DWorld *uLoadingWorld, U4DGameLogicInterface *uGameLogic){
     
        if (uGameWorld!=nullptr  && uGameLogic!=nullptr && uLoadingWorld!=nullptr) {
            
            loadingWorld=uLoadingWorld;
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            gameWorld=uGameWorld;
            gameController=sceneManager->getGameController();
            gameLogic=uGameLogic;
            pauseScene=false;
            sceneStateManager->changeState(U4DSceneLoadingState::sharedInstance());
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("The Game World, Loading World or the the Game Model (logic) are nullptr");
            
        }
        
        
    }

    void U4DScene::loadComponents(U4DWorld *uGameWorld, U4DGameLogicInterface *uGameLogic, U4DWorld *uEditingWorld){ 
        
        if (uGameWorld!=nullptr  && uGameLogic!=nullptr && uEditingWorld!=nullptr ) {
            
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            gameWorld=uGameWorld;
            gameController=sceneManager->getGameController();
            gameLogic=uGameLogic;
            
            editingWorld=uEditingWorld;
            
            sceneStateManager->changeState(U4DSceneEditingState::sharedInstance());
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("The Game World, Loading World or the the Game Model (logic) are nullptr");
            
        }
        
    }

    void U4DScene::initializeMultithreadofComponents(){
        
        std::thread t1(&U4DScene::loadMainWorldInBackground,this);
        
        t1.detach();
        
    }
    
    void U4DScene::loadMainWorldInBackground(){

        gameWorld->init();
        
        gameLogic->init();
        
        componentsMultithreadLoaded=true;
        
    }


    void U4DScene::update(float dt){
        
        //accumulate global time
        globalTime+=dt;
        
        //set up the time step
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        
        float frameTime=dt;
        
        //set the time step
        if (frameTime>0.25) {
            
            frameTime=0.25;
            
        }
        
        accumulator+=frameTime;
        
        while (accumulator>=timeStep) {
            
            //update state and physics engine
            getSceneStateManager()->update(timeStep);
            
            if (scene!=nullptr && scene->getPauseScene()==false) {
                //update the scheduler
                scheduler->tick(timeStep);
            }
            
            
            accumulator-=timeStep;
            
        }
        
        
    }

    void U4DScene::render(id <MTLCommandBuffer> uCommandBuffer){

        getSceneStateManager()->render(uCommandBuffer);
        
    }
    


    void U4DScene::determineVisibility(){
        
        if(sceneStateManager->getCurrentState()==U4DSceneActiveState::sharedInstance() || sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()){
            
            getGameWorld()->entityManager->determineVisibility();
            
        }
        
    }

    U4DControllerInterface* U4DScene::getGameController(){
        
        return gameController;
        
    }

    U4DWorld* U4DScene::getGameWorld(){
        
        if(sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()){
            return editingWorld;
        }
        return gameWorld;
    }

    U4DSceneStateManager *U4DScene::getSceneStateManager(){
        
        return sceneStateManager;
        
    }

    float U4DScene::getGlobalTime(){
        
        return globalTime;
    }


    void U4DScene::setAnchorMouse(bool uValue){
        
        anchorMouse=uValue;
    }
        
    bool U4DScene::getAnchorMouse(){ 
        
        return anchorMouse;
    }

    void U4DScene::setPauseScene(bool uValue){
        pauseScene=uValue;
    }

    bool U4DScene::getPauseScene(){
        return pauseScene;
    }

}

