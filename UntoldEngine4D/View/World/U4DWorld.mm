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
#include <regex>

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
        
        //grid box
        U4DVector3n gridPoint0(1.0,1.0,0.0);
        U4DVector3n gridPoint1(-1.0,-1.0,0.0);
        U4DVector3n gridPoint2(-1.0,1.0,0.0);
        U4DVector3n gridPoint3(-1.0,-1.0,0.0);
        U4DVector3n gridPoint4(1.0,1.0,0.0);
        U4DVector3n gridPoint5(1.0,-1.0,0.0);
        
        bodyCoordinates.addVerticesDataToContainer(gridPoint0);
        bodyCoordinates.addVerticesDataToContainer(gridPoint1);
        bodyCoordinates.addVerticesDataToContainer(gridPoint2);
        
        bodyCoordinates.addVerticesDataToContainer(gridPoint3);
        bodyCoordinates.addVerticesDataToContainer(gridPoint4);
        bodyCoordinates.addVerticesDataToContainer(gridPoint5);
        
    }
    
    void U4DWorld::changeVisibilityInterval(float uValue){
        
        entityManager->changeVisibilityInterval(uValue);
    }

    void U4DWorld::receiveUserInputUpdate(void *uData){
        
        U4DLayerManager *layerManager=U4DLayerManager::sharedInstance();
        
        U4DLayer *activeLayer=layerManager->getActiveLayer();
        
        controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
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
                
                delete tempChild;

                tempChild=nullptr;
                
            }else{
                child=child->prevInPreOrderTraversal();
            }
            
        }
        
        prevSibling=this;
        lastDescendant=this;
        next=nullptr;
    }

std::string U4DWorld::searchScenegraphForNextName(std::string uAssetName){

     //search the scenegraph for current names.
     //The following re will match "player.12" or "ball.1 for example
     std::string reString="("+uAssetName+")(\\.)(\\d{1,})";
     std::regex re(reString);
     std::smatch match;

     U4DEntity *child=this->next;

     int count=0;
     int highestEntityIndex=INT_MIN;

     while (child!=nullptr) {

         //strip all characters up to the period
         if(child->getEntityType()==U4DEngine::MODEL || child->getEntityType()==U4DEngine::PRIMITIVE){

             std::string s=child->getName();

             if (std::regex_match(s,match,re)) {

                 int entityIndex=std::stoi(match.str(3));

                 if (entityIndex>highestEntityIndex) {
                     highestEntityIndex=entityIndex;
                 }

                 count++;

             }
         }

         child=child->next;

     }

     //we are increasing the count by one. So, if the entity has an index of 12, such as player.12, the next one in line will be player.13. This will work regardless of how many player entities there are in the scenegraph
     if(highestEntityIndex>=count) count=highestEntityIndex+1;

     std::string modelName=uAssetName+"."+std::to_string(count);

     return modelName;
 }

}
