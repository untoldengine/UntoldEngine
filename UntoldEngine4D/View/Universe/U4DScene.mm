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
#include "U4DSceneActiveState.h"
#include "U4DSceneIdleState.h"
#include "U4DSceneLoadingState.h"
#include <thread>

namespace U4DEngine {
    
    //constructor
    U4DScene::U4DScene():sceneStateManager(nullptr),accumulator(0.0),globalTime(0.0),componentsMultithreadLoaded(false),anchorMouse(false){

        sceneStateManager=new U4DSceneStateManager(this);
        
    };

    //destructor
    U4DScene::~U4DScene(){

        delete sceneStateManager;
        
    };

    void U4DScene::loadComponents(U4DWorld *uGameWorld, U4DGameModelInterface *uGameModel){
        
        if (uGameWorld!=nullptr  && uGameModel!=nullptr) {
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            gameWorld=uGameWorld;
            gameController=sceneManager->getGameController();
            gameModel=uGameModel;
            
            gameWorld->setGameController(gameController);
            gameWorld->setGameModel(gameModel);
            
            gameController->setGameWorld(uGameWorld);
            gameController->setGameModel(gameModel);
            
            gameModel->setGameWorld(gameWorld);
            gameModel->setGameController(sceneManager->getGameController());
            gameModel->setGameEntityManager(gameWorld->getEntityManager());
            
            sceneStateManager->changeState(U4DSceneActiveState::sharedInstance());
            
        }else{
            
            std::cout<<"The Game World or the the Game Model (logic) are nullptr"<<std::endl;
        }
        
    
    }

    void U4DScene::loadComponents(U4DWorld *uGameWorld, U4DWorld *uLoadingWorld, U4DGameModelInterface *uGameModel){
     
        if (uGameWorld!=nullptr  && uGameModel!=nullptr && uLoadingWorld!=nullptr) {
            
            loadingWorld=uLoadingWorld;
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            gameWorld=uGameWorld;
            gameController=sceneManager->getGameController();
            gameModel=uGameModel;
            
            gameWorld->setGameController(gameController);
            gameWorld->setGameModel(gameModel);
            
            gameController->setGameWorld(uGameWorld);
            gameController->setGameModel(gameModel);
            
            gameModel->setGameWorld(gameWorld);
            gameModel->setGameController(sceneManager->getGameController());
            gameModel->setGameEntityManager(gameWorld->getEntityManager());
            
            sceneStateManager->changeState(U4DSceneLoadingState::sharedInstance());
            
        }else{
            
            std::cout<<"The Game World, Loading World or the the Game Model (logic) are nullptr"<<std::endl;
        }
        
        
    }

    void U4DScene::initializeMultithreadofComponents(){
        
        std::thread t1(&U4DScene::loadMainWorldInBackground,this);
        
        t1.detach();
        
    }
    
    void U4DScene::loadMainWorldInBackground(){

        gameWorld->init();
        
        gameModel->init();
        
        componentsMultithreadLoaded=true;
        
    }


    void U4DScene::update(float dt){
        
        //accumulate global time
        globalTime+=dt;
        
        //set up the time step
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        
        float frameTime=dt;
        
        //set the time step
        if (frameTime>0.25) {
            
            frameTime=0.25;
            
        }
        
        accumulator+=frameTime;
        
        while (accumulator>=timeStep) {
            
            //update state and physics engine
            getSceneStateManager()->update(timeStep);
            
            //update the scheduler
            scheduler->tick(timeStep);
            
            accumulator-=timeStep;
            
        }
        
        
    }

    void U4DScene::render(id <MTLRenderCommandEncoder> uRenderEncoder){

        getSceneStateManager()->render(uRenderEncoder);
        
    }
    
    void U4DScene::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        getSceneStateManager()->renderShadow(uRenderShadowEncoder, uShadowTexture);
        
    }

    void U4DScene::renderOffscreen(id <MTLRenderCommandEncoder> uOffscreenRenderEncoder, id<MTLTexture> uOffscreenTexture){
        
        getSceneStateManager()->renderOffscreen(uOffscreenRenderEncoder, uOffscreenTexture);
    }


    void U4DScene::determineVisibility(){
        
        if(sceneStateManager->getCurrentState()==U4DSceneActiveState::sharedInstance()){
            
            gameWorld->entityManager->determineVisibility();
            
        }
        
    }

    U4DControllerInterface* U4DScene::getGameController(){
        
        return gameController;
        
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

}

