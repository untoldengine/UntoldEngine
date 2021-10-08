//
//  SandboxEditWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "SandboxEditWorld.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DDebugger.h"
#include "U4DSkybox.h"
#include "U4DModelPipeline.h"
#include "U4DDynamicAction.h"

#include "Player.h"
#include "Field.h"

#include "U4DEntityFactory.h"
#include "U4DSerializer.h"

using namespace U4DEngine;

SandboxEditWorld::SandboxEditWorld(){
    
}

SandboxEditWorld::~SandboxEditWorld(){
    
}

void SandboxEditWorld::init(){
    
    /*----DO NOT REMOVE. THIS IS REQUIRED-----*/
    //Configures the perspective view, shadows, lights and camera.
    setupConfiguration();
    /*----END DO NOT REMOVE.-----*/
    
    //The following code snippets loads scene data, renders the characters and skybox.
    
    setEnableGrid(true);
    
    //register the classes
    
    U4DEngine::U4DEntityFactory *entityFactory=U4DEngine::U4DEntityFactory::sharedInstance();

    entityFactory->registerClass<Player>("Player");
    entityFactory->registerClass<Field>("Field");
    
//    Player *models[3];
//
//    for(int i=0;i<sizeof(models)/sizeof(models[0]);i++){
//
//            models[i]=new Player();
//
//            if (models[i]->init("player0")) {
//
//                addChild(models[i]);
//
//            }
//        }
//
//    Field *field=new Field();
//    if (field->init("field")) {
//        addChild(field);
//
//    }
    
    
    //deserialize
    U4DEngine::U4DSerializer *serializer=U4DSerializer::sharedInstance();

    serializer->deserialize("scenefile.u4d");

    
//    std::map<std::string,std::string> sceneModelMap;
//
//    sceneModelMap["oppositeplayer0"]="U4DModel";
//    sceneModelMap["player0"]="Player";
//    sceneModelMap["field"]="Field";
//
//    //iterate through the map
//
//    std::map<std::string,std::string>::iterator it;
//
//    for(it=sceneModelMap.begin();it!=sceneModelMap.end();it++){
//
//        U4DModel *n=entityFactory->createAction(it->second);
//
//        if (n!=nullptr) {
//
//            if(it->second.compare("U4DModel")==0){
//
//                if (n->loadModel(it->first.c_str())) {
//
//                    n->loadRenderingInformation();
//                    addChild(n);
//
//                }
//
//            }else{
//
//                if (n->init(it->first.c_str())) {
//                    addChild(n);
//                }
//
//            }
//        }
//    }
        
        
//    U4DModel *player=entityFactory->createAction("Player");
//    if(player->init("player0")){
//
//        addChild(player);
//    }

    
//    U4DModel *field=entityFactory->createAction("Field");
//
//    if(field->init("field")){
//
//        addChild(field);
//
//    }
    
//    U4DModel *model=entityFactory->createAction("Model");
//    if (model->loadModel("oppositeplayer0")) {
//
//        model->loadRenderingInformation();
//        addChild(model);
//    }

    

//    //Line 3. Load attribute (rendering information) into the game entity
//    if (player->loadModel("player0")) {
//
//        player->setPipeline("testPipeline");
//
////        U4DEngine::U4DDynamicAction *kineticAction=new U4DDynamicAction(player);
////
////        kineticAction->enableKineticsBehavior();
////
////        kineticAction->enableCollisionBehavior();
//
//        //Line 4. Load rendering information into the GPU
//        player->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(player);
//
//        //player->translateBy(0.0, 10.0, 0.0);
//
//    }
    
//    //Create an instance of U4DGameObject type
//    U4DEngine::U4DModel *ground=new U4DEngine::U4DModel();
//
//    //Line 3. Load attribute (rendering information) into the game entity
//    if (ground->loadModel("field")) {
//
//        //ground->setPipeline("testPipeline");
//
////        U4DEngine::U4DDynamicAction *gkinetic=new U4DDynamicAction(ground);
////
////        //gkinetic->enableKineticsBehavior();
////
////        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
////
////        gkinetic->setGravity(zero);
////
////        gkinetic->enableCollisionBehavior();
//
//        //Line 4. Load rendering information into the GPU
//        ground->loadRenderingInformation();
//
//        //Line 5. Add astronaut to the scenegraph
//        addChild(ground);
//
//    }
    
}


void SandboxEditWorld::update(double dt){
    
}

//Sets the configuration for the engine: Perspective view, shadows, light
void SandboxEditWorld::setupConfiguration(){
    
    //Get director object
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //Compute the perspective space matrix
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(65.0f, director->getAspect(), 0.001f, 400.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //Compute the orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    //Get camera object and translate it to position
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();

    U4DEngine::U4DVector3n cameraPosition(0.0,3.0,-12.0);

    
    //translate camera
    camera->translateTo(cameraPosition);
    
    //set origin point
    U4DVector3n origin(0,0,0);
    
    //Create light object, translate it and set diffuse and specular color
    U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
    light->translateTo(10.0,10.0,-10.0);
    U4DEngine::U4DVector3n diffuse(0.5,0.5,0.5);
    U4DEngine::U4DVector3n specular(0.2,0.2,0.2);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    
    addChild(light);
    
    //Set the view direction of the camera and light
    //camera->viewInDirection(origin);
    
    light->viewInDirection(origin);
    
    //set the poly count to 5000. Default is 3000
    director->setPolycount(5000);
}
