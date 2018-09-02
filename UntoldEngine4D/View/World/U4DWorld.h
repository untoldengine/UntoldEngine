//
//  U4DWorld.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DWorld__
#define __MVCTemplate__U4DWorld__


#include <iostream>
#include <vector>
#include "U4DEntity.h"
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"
#include "CommonProtocols.h"

#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {
    
    class U4DEntity;
    class U4DControllerInterface;
    class U4DGameModelInterface;
    class U4DEntityManager;
    class U4DLights;
}

namespace U4DEngine {
    
/**
 @ingroup gameobjects
 @brief The U4DWorld class represents the View Component of the Model-View-Controller pattern.
 */
class U4DWorld:public U4DVisibleEntity{
    
private:
    
    U4DControllerInterface *gameController;
    
    U4DGameModelInterface *gameModel;
    
    bool enableGrid;
    
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
    
    void setGameModel(U4DGameModelInterface *uGameModel);
    
    U4DControllerInterface* getGameController();
    
    U4DGameModelInterface* getGameModel();
    
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    void buildGrid();
    
    void setEnableGrid(bool uValue);
    
    U4DEntityManager *getEntityManager();
    
};
    
}

#endif /* defined(__MVCTemplate__U4DWorld__) */
