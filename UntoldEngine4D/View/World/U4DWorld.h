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
#include "U4DRenderEntity.h"

namespace U4DEngine {
    
    class U4DEntity;
    class U4DControllerInterface;
    class U4DGameLogicInterface;
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
    
    /**
     @brief pointer to the game controller
     */
    U4DControllerInterface *gameController;
    
    /**
     @brief pointer to the game model
     */
    U4DGameLogicInterface *gameLogic;
    
    /**
     @brief enables grid variable
     */
    bool enableGrid;
    
public:
    
    /**
     @brief pointer to the entity manager
     */
    U4DEntityManager *entityManager;
    
    /**
     @brief Object which contains attribute data such as vertices
     */
    U4DVertexData bodyCoordinates;
    
    /**
     @brief class constructor
     */
    U4DWorld();
    
    /**
     @brief class destructor
     */
    virtual ~U4DWorld();
    
    /**
     @brief copy constructor
     */
    U4DWorld(const U4DWorld& value);
    
    /**
     @brief copy constructor
     */
    U4DWorld& operator=(const U4DWorld& value);
    
    /**
     @brief Initialization method for the game
     @details All game objects should be created, initialized and added into the scenegraph here.
     */
    virtual void init(){};
    
    /**
     @brief Method which updates the state of the World
     
     @param dt Time-step value
     */
    void update(double dt){};
    
    
    /**
     @brief sets the game controller interface
     @details the game controller interface could be use iOS touch, Game pads, mouse/keyboard, etc

     @param uGameController game controller interface
     */
    void setGameController(U4DControllerInterface* uGameController);
    
    
    /**
     @brief sets the game model (logic) for the game

     @param uGameLogic pointer to the game logic interface
     */
    void setGameLogic(U4DGameLogicInterface *uGameLogic);
    
    
    /**
     @brief gets the game controller interface used in the game. Such as iOS touch, gamepads, mouse/keyboard, etc

     @return game controller interface
     */
    U4DControllerInterface* getGameController();
    
    
    /**
     @brief gets the game model (logic) interface.

     @return pointer to the game model interface
     */
    U4DGameLogicInterface* getGameLogic();
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix, any rendering flags. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    
    /**
     @brief renders the grid in the world
     @details the grid consists of white lines going across the x-axis and z-axis
     */
    void buildGrid();
    
    
    /**
     @brief sets whether or not to render the world grid

     @param uValue true to render the world grid. False otherwise
     */
    void setEnableGrid(bool uValue);
    
    
    /**
     @brief gets the pointer to the game entity manager

     @return pointer to the entity manager
     */
    U4DEntityManager *getEntityManager();
    
    /**
     @brief change the current visibility interval. The default is 0.5.
     @details This interval determines how fast the BVH is computed to determine which 3D models are within the camera frustum. The lower this interval, the faster the BVH is computed.
     @param uValue time interval.
     */
    void changeVisibilityInterval(float uValue);
    
    void receiveUserInputUpdate(void *uData);

    void removeAllModelChildren();
};
    
}

#endif /* defined(__MVCTemplate__U4DWorld__) */
