//
//  U4DEntityFactory.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DEntityFactory.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DLogger.h"
#include "U4DMatchManager.h"

namespace U4DEngine{

U4DEntityFactory *U4DEntityFactory::instance=0;

U4DEntityFactory::U4DEntityFactory(){
    
    registerClass<U4DModel>("U4DModel");
}

U4DEntityFactory::~U4DEntityFactory(){
    
}

U4DEntityFactory* U4DEntityFactory::sharedInstance(){
    
    if(instance==0){
        instance=new U4DEntityFactory();
    }
    
    return instance;
}

std::vector<std::string> U4DEntityFactory::getRegisteredClasses(){
    
    std::map<std::string,pCreateAction>::iterator it;
    std::vector<std::string> registeredClassesContainer;
    
    for(it=createActionMap.begin();it!=createActionMap.end();it++){

        std::string n=it->first;
        
        registeredClassesContainer.push_back(n);
    }
    
    return registeredClassesContainer;
}

void U4DEntityFactory::createModelInstance(std::string uAssetName, std::string uModelName, std::string uType, const char* uExtraInfo, ...){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    
    logger->log("Creating instance of type %s for asset name %s",uType.c_str(),uAssetName.c_str());
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();
    U4DModel *model=createAction(uType);
    
    bool modelDataLoaded=false;

    if (model!=nullptr) {
        
        if(uType.compare("U4DModel")==0){

            if (model->loadModel(uAssetName.c_str())) {
                
                model->loadRenderingInformation();
                world->addChild(model);
                modelDataLoaded=true;
            }

        }else{

            if (model->init(uAssetName.c_str())) {
                
                world->addChild(model);
                modelDataLoaded=true;
            }

        }
        
        if (modelDataLoaded) {
            
            model->setName(uModelName);
            model->setAssetReferenceName(uAssetName);
            
            //set the class type
            model->setClassType(uType);
            
            //if the class type is of U4DPlayer, then check if a team was selected
            
            if(uType.compare("U4DPlayer")==0){
            
                U4DMatchManager *matchManager=U4DMatchManager::sharedInstance();
                
                va_list args;
                va_start (args, uExtraInfo);
                
                while (uExtraInfo) {
                    
                    if(std::strcmp(uExtraInfo,"TeamA")==0){
                        
                        matchManager->teamA->addPlayer(reinterpret_cast<U4DPlayer*>(model));
                        
                    }else if(std::strcmp(uExtraInfo,"TeamB")==0){
                        
                        matchManager->teamB->addPlayer(reinterpret_cast<U4DPlayer*>(model));
                       
                    }
                    
                    uExtraInfo=va_arg(args, const char *);
                }

                va_end (args);
                
            }
            
        }
        
        
    }else{
        
        logger->log("Error: Unable to create instance of type %s for asset %s",uType.c_str(),uAssetName.c_str());
        
    }
    
}



void U4DEntityFactory::createModelInstance(std::string uAssetName, std::string uModelName, std::string uType, std::string uTeam, U4DVector3n uPosition, U4DVector3n uOrientation){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Creating instance of type %s for asset name %s",uType.c_str(),uAssetName.c_str());
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();

    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();

    U4DModel *model=createAction(uType);
    bool modelDataLoaded=false;
    
    if (model!=nullptr) {

        if(uType.compare("U4DModel")==0){

            if (model->loadModel(uAssetName.c_str())) {
                
                model->loadRenderingInformation();
                world->addChild(model);
                modelDataLoaded=true;

            }

        }else{

            if (model->init(uAssetName.c_str())) {
                
                world->addChild(model);
                modelDataLoaded=true;
                
            }

        }
        
        if (modelDataLoaded) {
            
            model->setName(uModelName);
            model->setAssetReferenceName(uAssetName);
            
            //set the class type
            model->setClassType(uType);
            
            if(uType.compare("U4DPlayer")==0){
                
                U4DMatchManager *matchManager=U4DMatchManager::sharedInstance();
                    
                if(uTeam.compare("TeamA")==0){
                    
                    matchManager->teamA->addPlayer(reinterpret_cast<U4DPlayer*>(model));
                    
                }else if(uTeam.compare("TeamB")==0){
                    
                    matchManager->teamB->addPlayer(reinterpret_cast<U4DPlayer*>(model));
                   
                }
                    
            }
            
            model->translateTo(uPosition);
            model->rotateTo(uOrientation.x, uOrientation.y, uOrientation.z);
        }
        
        
    }else{
        
        logger->log("Error: Unable to create instance of type %s for asset %s",uType.c_str(),uAssetName.c_str());
        
    }
}

}
