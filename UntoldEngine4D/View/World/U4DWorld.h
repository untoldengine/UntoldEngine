//
//  U4DWorld.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DWorld__
#define __MVCTemplate__U4DWorld__


#include <iostream>
#include <vector>
#include "U4DEntity.h"
#include "U4DVisibleEntity.h"
#include "U4DOpenGLWorld.h"
#include "U4DVertexData.h"
#include "CommonProtocols.h"

#import <GLKit/GLKit.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DControllerInterface;
    class U4DEntityManager;
    class U4DLights;
}

namespace U4DEngine {
    
class U4DWorld:public U4DVisibleEntity{
    
private:
    
    U4DControllerInterface *gameController;
    
    bool gridEnabled;
    bool shadowsEnabled;
    
    U4DVector3n gravity;
    
public:
    U4DEntityManager *entityManager;
    U4DVertexData bodyCoordinates;
    
    //constructor
    U4DWorld();
    
    //destructor
    virtual ~U4DWorld(){};
    
    //copy constructor
    U4DWorld(const U4DWorld& value);
    
    U4DWorld& operator=(const U4DWorld& value);
    
    virtual void init(){};
    
    void update(double dt){};
    
    void setGameController(U4DControllerInterface* uGameController);
    
    void setEntityControlledByController(U4DEntity *uEntity);
    
    void initLoadingModels();
    
    void buildGrid();
    
    void enableGrid(bool value);
    
    void draw();
    
    void enableShadows();
    
    void disableShadows();
    
    void startShadowMapPass();
    
    void endShadowMapPass();
    
    void getShadows();
    
    void setGravity(U4DVector3n& uGravity);
    
    U4DVector3n getGravity();
    
    
};
    
}

#endif /* defined(__MVCTemplate__U4DWorld__) */
