//
//  U4DEntityFactory.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/1/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DEntityFactory.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DLogger.h"

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

void U4DEntityFactory::createModelInstance(std::string uAssetName, std::string uType){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Creating instance of type %s for asset name %s",uType.c_str(),uAssetName.c_str());
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();

    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();

    U4DModel *model=createAction(uType);

    if (model!=nullptr) {

        if(uType.compare("U4DModel")==0){

            if (model->loadModel(uAssetName.c_str())) {

                model->loadRenderingInformation();
                world->addChild(model);

            }

        }else{

            if (model->init(uAssetName.c_str())) {
                world->addChild(model);
            }

        }
    }else{
        
        logger->log("Error: Unable to create instance of type %s for asset %s",uType.c_str(),uAssetName.c_str());
        
    }
}

}
