//
//  U4DScene.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DScene__
#define __MVCTemplate__U4DScene__

#include <iostream>
#include <vector>
#include "U4DEntityManager.h"
#include "U4DWorld.h"
#include "U4DControllerInterface.h"
#include "U4DGameLogicInterface.h"

namespace U4DEngine{

    class U4DSceneStateInterface;
    class U4DSceneStateManager;

}

namespace U4DEngine {
    
/**
 @ingroup scene
 @brief The U4DScene class represents the scene (universe) object of the game. A scene can have multiple worlds. A world represents the View Component of the Model-View-Controller pattern.
 */
class U4DScene{
    
private:
    
    
    /**
     @brief Time step accumulator
     */
    float accumulator;
    
    /**
     @brief global time since game started
     */
    float globalTime;
    
    /**
     @brief Anchor mouse to center of the screen
     */
    bool anchorMouse;
    
public:
    
    /**
     @brief class constructor
     */
    U4DScene();

    /**
     @brief class destructor
     */
    virtual ~U4DScene();
    
    /**
     @brief copy constructor
     */
    U4DScene(const U4DScene& value){};
    
    /**
     @brief copy constructor
     */
    U4DScene& operator=(const U4DScene& value){return *this;};
    
    /**
     @brief init method.
     */
    virtual void init(){};
    
    /**
     @brief pointer to the game controller interface
     */
    U4DControllerInterface *gameController;
    
    /**
     @brief pointer to the world class
     */
    U4DWorld* gameWorld;
    
    /**
     @brief pointer to the world class representing the loading world
     */
    U4DWorld *loadingWorld;
    
    /**
     @brief Used to confirm if the loading and world scene are loading simultaneously
     */
    bool componentsMultithreadLoaded;
    
    /**
     @brief pointer to the game model(logic) interface
     */
    U4DGameLogicInterface *gameLogic;
    
    /**
     @brief Pointer to the scene state manager
     */
    U4DSceneStateManager *sceneStateManager;
    
    /**
     @brief Gets the pointer to the scene manager
     */
    U4DSceneStateManager *getSceneStateManager();
    
    /**
     @brief sets the pointer for the world, controller and logic classes

     @param uGameWorld pointer to the world object
     @param uGameLogic pointer to the game logic interface
     */
    virtual void loadComponents(U4DWorld *uGameWorld, U4DGameLogicInterface *uGameLogic) final;
    
    /**
    @brief sets the pointer for the world, controller and logic classes and the loading world

    @param uGameWorld pointer to the world object
    @param uLoadingWorld pointer to the loading world object
    @param uGameLogic pointer to the game logic interface
    */
    virtual void loadComponents(U4DWorld *uGameWorld, U4DWorld *uLoadingWorld, U4DGameLogicInterface *uGameLogic) final;
    
    /**
     @brief Method in charge of updating the states of each entity
     
     @param dt time value
     */
    virtual void update(float dt) final;
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    virtual void render(id <MTLCommandBuffer> uCommandBuffer) final;
    
    
    U4DControllerInterface *getGameController();
    
    /**
     @brief determines if the current entity is within the camera frustum
     @details any 3D model outside of the frustum are not rendered
     */
    void determineVisibility();
    
    /**
     @brief Returns the global time
     
     @return The global time since the game started. Mainly used for the shaders
     */
    float getGlobalTime();
    
    /**
    @brief Initiates world in the background while the loading world is playing.
    */
    void loadMainWorldInBackground();
    
    /**
    @brief Initiates the multi-thread of the world and loading-world objects
    */
    void initializeMultithreadofComponents();
    
    /**
     @brief Anchor mouse to center of screen
     */
    void setAnchorMouse(bool uValue);
    
    /**
     @brief get if mouse should be anhored to the center of the screen
     */
    bool getAnchorMouse();
    
};

}

#endif /* defined(__MVCTemplate__U4DScene__) */
