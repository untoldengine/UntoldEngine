//
//  U4DScene.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DDirector.h"
#include "U4DTouches.h"

namespace U4DEngine {
    
    //constructor
    U4DScene::U4DScene(){
        
        

    };

    //destructor
    U4DScene::~U4DScene(){
        
        

    };

    void U4DScene::setGameWorldControllerAndModel(U4DWorld *uGameWorld,U4DControllerInterface *uGameController, U4DGameModelInterface *uGameModel){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        director->setScene(this);
        
        gameWorld=uGameWorld;
        gameController=uGameController;
        gameModel=uGameModel;
        
        gameWorld->setGameController(gameController);
        gameWorld->setGameModel(gameModel);
        
        gameController->setGameWorld(uGameWorld);
        gameController->setGameModel(gameModel);
        
        gameModel->setGameWorld(gameWorld);
        gameModel->setGameController(uGameController);
        gameModel->setGameEntityManager(gameWorld->getEntityManager());
        
        gameWorld->init();
        gameController->init();
        gameModel->init();
    
    }


    void U4DScene::update(float dt){
        
        gameModel->update(dt);
        
        //update the entity manager
        gameWorld->entityManager->update(dt); //need to add dt to view
        
        gameController->update(dt);
    }

    void U4DScene::render(id <MTLRenderCommandEncoder> uRenderEncoder){

        gameWorld->entityManager->render(uRenderEncoder);
        gameController->render(uRenderEncoder);
        
    }
    
    void U4DScene::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        gameWorld->entityManager->renderShadow(uRenderShadowEncoder, uShadowTexture);
    }


    void U4DScene::determineVisibility(){
        
        gameWorld->entityManager->determineVisibility();
        
    }
    
    void U4DScene::touchBegan(const U4DTouches &touches){
        
        gameController->touchBegan(touches);
    }

    void U4DScene::touchEnded(const U4DTouches &touches){
        
        gameController->touchEnded(touches);
    }

    void U4DScene::touchMoved(const U4DTouches &touches){
        
        gameController->touchMoved(touches);
    }

    void U4DScene::init(){
        
    }
    
}

