//
//  Earth.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "Earth.h"

#include "CommonProtocols.h"

#include <stdio.h>

#include "U4DDirector.h"

#include "U4DMatrix3n.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"

#include "GameAsset.h"

using namespace U4DEngine;

void Earth::init(){
        
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,5.0,-100.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(30.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,100.0,-100.0);
    
    addChild(light);
    
    //camera->viewInDirection(origin);

    //light->viewInDirection(origin);


    //load tree
    for(int i=0;i<34;i++){

        std::string name="tree";
        name+=std::to_string(i+1);

        tree[i]=new GameAsset();

        if(tree[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(tree[i]);

        }

    }

    //load bridge
    for(int i=0;i<4;i++){

        std::string name="bridge";
        name+=std::to_string(i+1);

        bridge[i]=new GameAsset();

        if(bridge[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(bridge[i]);

        }

    }

    //load clouds
    for(int i=0;i<12;i++){

        std::string name="cloud";
        name+=std::to_string(i+1);

        cloud[i]=new GameAsset();

        if(cloud[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(cloud[i]);

        }

    }

    //load fence
    for(int i=0;i<5;i++){

        std::string name="fence";
        name+=std::to_string(i+1);

        fence[i]=new GameAsset();

        if(fence[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(fence[i]);

        }

    }

    //load grass
    for(int i=0;i<10;i++){

        std::string name="grass";
        name+=std::to_string(i+1);

        grass[i]=new GameAsset();

        if(grass[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(grass[i]);

        }

    }
    
    //load land
    for(int i=0;i<4;i++){
        
        std::string name="land";
        name+=std::to_string(i+1);
        
        land[i]=new GameAsset();
        
        if(land[i]->init(name.c_str(), "blenderscript.u4d")){
            
            addChild(land[i]);
            
        }
        
    }
    
    //load moss
    for(int i=0;i<6;i++){

        std::string name="moss";
        name+=std::to_string(i+1);

        moss[i]=new GameAsset();

        if(moss[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(moss[i]);

        }

    }
    
    
    //load stone

    for(int i=0;i<7;i++){

        std::string name="stone";
        name+=std::to_string(i+1);

        stone[i]=new GameAsset();

        if(stone[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(stone[i]);

        }

    }



    //load trunk
    for(int i=0;i<5;i++){

        std::string name="trunk";
        name+=std::to_string(i+1);

        trunk[i]=new GameAsset();

        if(trunk[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(trunk[i]);

        }

    }

    //load weed
    for(int i=0;i<4;i++){

        std::string name="weed";
        name+=std::to_string(i+1);

        weed[i]=new GameAsset();

        if(weed[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(weed[i]);

        }

    }

    //load chosa
    chosa=new GameAsset();
    if(chosa->init("chosa", "blenderscript.u4d")){
        addChild(chosa);
    }


    //load fireplace
    fireplace=new GameAsset();

    if(fireplace->init("fireplace", "blenderscript.u4d")){
        addChild(fireplace);
    }
    
    
    ocean=new GameAsset();
    
    if(ocean->init("ocean", "blenderscript.u4d")){
        
        addChild(ocean);
        
    }
    
    
}

void Earth::update(double dt){

    U4DLights *light=U4DLights::sharedInstance();
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    U4DVector3n cameraPos=camera->getAbsolutePosition();
    cameraPos.y=20.0;
    light->translateTo(cameraPos);
   
}





