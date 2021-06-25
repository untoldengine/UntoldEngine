//
//  U4DWorld.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DWorld.h"
#include "U4DControllerInterface.h"
#include "U4DGameLogicInterface.h"
#include "U4DEntityManager.h"
#include "CommonProtocols.h"
#include "U4DModel.h"
#include "U4DLayer.h"
#include "U4DEntity.h"
#include "U4DLayerManager.h"
#include "U4DRenderWorld.h"

namespace U4DEngine {
    
    //constructor
    U4DWorld::U4DWorld():enableGrid(false){
        
        entityManager=new U4DEntityManager();
        entityManager->setRootEntity(this);
        
        renderEntity=new U4DRenderWorld(this);
        
        renderEntity->setPipelineForPass("worldpipeline",U4DEngine::finalPass);
        
        buildGrid();
        renderEntity->loadRenderingInformation();
        
    }
    
    
    //copy constructor
    U4DWorld::U4DWorld(const U4DWorld& value){
    
    }
    
    U4DWorld& U4DWorld::operator=(const U4DWorld& value){
    
        return *this;
    
    }

    U4DWorld::~U4DWorld(){
        
        //set root entity to null
        entityManager->setRootEntity(nullptr);
        
        delete entityManager;
        delete renderEntity;
        
    }
    
    U4DEntityManager* U4DWorld::getEntityManager(){
        return entityManager;
    }
    

    void U4DWorld::setGameController(U4DControllerInterface* uGameController){
        
        gameController=uGameController;
        
    }
    
    void U4DWorld::setGameLogic(U4DGameLogicInterface *uGameLogic){
        
        gameLogic=uGameLogic;
        
    }
    
    U4DControllerInterface* U4DWorld::getGameController(){
        
        return gameController;
    }
    
    U4DGameLogicInterface* U4DWorld::getGameLogic(){
        
        return gameLogic;
    }

    void U4DWorld::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (enableGrid) {
            renderEntity->render(uRenderEncoder);
        }
    }
    
    void U4DWorld::setEnableGrid(bool uValue){
        
        enableGrid=uValue;
    }
    
    void U4DWorld::buildGrid(){
        
        int gridsize=8;
        
        //grid box
        U4DVector3n backLeftCorner(-gridsize,0,-gridsize);
        U4DVector3n backRightCorner(gridsize,0,-gridsize);
        U4DVector3n frontLeftCorner(-gridsize,0,gridsize);
        U4DVector3n frontRightCorner(gridsize,0,gridsize);
        
        bodyCoordinates.addVerticesDataToContainer(backLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(backRightCorner);
        
        bodyCoordinates.addVerticesDataToContainer(backLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(frontLeftCorner);
        
        bodyCoordinates.addVerticesDataToContainer(backRightCorner);
        bodyCoordinates.addVerticesDataToContainer(frontRightCorner);
        
        bodyCoordinates.addVerticesDataToContainer(frontLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(frontRightCorner);
        
        //grid lines
        for (int x=-gridsize; x<=gridsize; x++) {
            
            U4DVector3n startBackPoint(x,0,-gridsize);
            U4DVector3n endFrontPoint(x,0,gridsize);
            
            bodyCoordinates.addVerticesDataToContainer(startBackPoint);
            bodyCoordinates.addVerticesDataToContainer(endFrontPoint);
            
            U4DVector3n startLeftPoint(-gridsize,0,x);
            U4DVector3n endRightPoint(gridsize,0,x);
            
            bodyCoordinates.addVerticesDataToContainer(startLeftPoint);
            bodyCoordinates.addVerticesDataToContainer(endRightPoint);
            
        }
        
        //grid vertical line
        
        U4DVector3n startVerticalPoint(0,-2,0);
        U4DVector3n endVerticalPoint(0,2,0);
        
        bodyCoordinates.addVerticesDataToContainer(startVerticalPoint);
        bodyCoordinates.addVerticesDataToContainer(endVerticalPoint);
        
        
    }
    
    void U4DWorld::changeVisibilityInterval(float uValue){
        
        entityManager->changeVisibilityInterval(uValue);
    }

    void U4DWorld::receiveUserInputUpdate(void *uData){
        
        U4DLayerManager *layerManager=U4DLayerManager::sharedInstance();
        
        U4DLayer *activeLayer=layerManager->getActiveLayer();
        
        CONTROLLERMESSAGE &controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        U4DEngine::INPUTELEMENTACTION inputAction=static_cast<U4DEngine::INPUTELEMENTACTION>(controllerInputMessage.inputElementAction);
        
        //Go through the layer's children and check if the input coordinates lie within their boundaries
        if (activeLayer!=nullptr) {
            
            U4DEntity *child=activeLayer->getLastChild();
            
            while (child!=nullptr) {
                
                if(child->changeState(inputAction, controllerInputMessage.inputPosition)){
                    
                    //mute the message since it was handle by the UI element
                    controllerInputMessage.inputElementAction=-1;
                    controllerInputMessage.inputElementType=-1;
                    
                }
                
                child=child->getPrevSibling();
                
            }
            
        }
        
    }

    void U4DWorld::removeAllModelChildren(){
            
        U4DEntity *child=lastDescendant;
        
        while (child!=nullptr) {
            
            if (child==this) break;
            
            if (child->getEntityType()==U4DEngine::MODEL) {
                
                U4DModel *tempChild=dynamic_cast<U4DModel*>(child); 
                
                child=child->prevInPreOrderTraversal();
                
                removeChild(tempChild);
                
//                delete tempChild;
//
//                tempChild=nullptr;
                
            }else{
                child=child->prevInPreOrderTraversal();
            }
            
        }
        
        prevSibling=this;
        lastDescendant=this;
        next=nullptr;
    }

}
