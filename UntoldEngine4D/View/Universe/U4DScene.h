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
#include "U4DGameModelInterface.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
class U4DTouches;
}

namespace U4DEngine {
    
/**
 @ingroup gameobjects
 @brief The U4DScene class represents the scene (universe) object of the game. A scene can have multiple worlds. A world represents the View Component of the Model-View-Controller pattern.
 */
class U4DScene{
    
private:
    
    /**
     @brief pointer to the game controller interface
     */
    U4DControllerInterface *gameController;
    
    /**
     @brief pointer to the world class
     */
    U4DWorld* gameWorld;
    
    /**
     @brief pointer to the game model(logic) interface
     */
    U4DGameModelInterface *gameModel;
    
public:
    
    /**
     @brief class constructor
     */
    U4DScene();

    /**
     @brief class destructor
     */
    ~U4DScene();
    
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
    virtual void init();
    
    
    /**
     @brief sets the pointer for the world, controller and logic classes

     @param uGameWorld pointer to the world object
     @param uGameController pointer to the game controller interface
     @param uGameModel pointer to the game model interface
     */
    virtual void setGameWorldControllerAndModel(U4DWorld *uGameWorld,U4DControllerInterface *uGameController, U4DGameModelInterface *uGameModel) final;
    
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
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder) final;
    
    /**
     * @brief Renders the shadow for a 3D entity
     * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
     *
     * @param uShadowTexture Texture shadow for the current entity
     */
    virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture) final;
    
    /**
     @brief Method which informs the engine that a touch event has started
     
     @param touches touch event
     */
    void touchBegan(const U4DTouches &touches);
    
    /**
     @brief Method which informs the engine that a touch event has ended
     
     @param touches touch event
     */
    void touchEnded(const U4DTouches &touches);
    
    /**
     @brief Method which informs the engine that a touch event is moving
     
     @param touches touch event
     */
    void touchMoved(const U4DTouches &touches);
    
    /**
     * @brief A press on the game pad has began
     * @details Engine detected a button press from the gamepad
     *
     * @param uGamePadElement Game pad element such as button, pad arrows
     * @param uGamePadAction action detected on the gamepad
     */
    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     * @brief A release on the game pad was detected
     * @details The engine deteced a button release from the game gamepad
     *
     * @param uGamePadElement Game pad element such as button, pad arrows
     * @param uGamePadAction action detected on the gamepad
     */
    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     * @brief The joystick on the game pad was moved
     * @details The engine detected joystick movement on the game pad
     *
     * @param uGamePadElement game pad element such as left or right joystick
     * @param uGamePadAction action detected
     * @param uPadAxis movement direction of the joystick
     */
    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
    
    /**
     * @brief A key press on the mac was detected
     * @details The engine detected a key press
     *
     * @param uKeyboardElement keyboard element such as a particular key
     * @param uKeyboardAction action on the key
     */
    void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
    
    /**
     * @brief A key release on the mac was detected
     * @details the engine detected a key release
     *
     * @param uKeyboardElement keyboard element such as a key
     * @param uKeyboardAction action on the key
     */
    void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
    
    /**
     * @brief The arrow key is currently pressed
     * @details the engine has detected the arrow key being currently pressed
     *
     * @param uKeyboardElement keyboard element such as the up, down, right, left key
     * @param uKeyboardAction action on the key
     * @param uPadAxis axis of the currently key being pressed. For example, the up arrow key will provide an axis of (0.0,1.0)
     */
    void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
    
    /**
     * @brief The mouse was pressed
     * @details The engine has detected a mouse press
     *
     * @param uMouseElement mouse element such as the right or left click
     * @param uMouseAction action on the mouse
     * @param uMouseAxis
     */
    void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     * @brief The mouse was released
     * @details the engine has detected a mouse release
     *
     * @param uMouseElement mouse element such as left or righ button
     * @param uMouseAction action on the mouse
     */
    void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction);
    
    /**
     * @brief The mouse is being moved
     * @details The engine has detected mouse movement
     *
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
     */
    void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     @brief determines if the current entity is within the camera frustum
     @details any 3D model outside of the frustum are not rendered
     */
    void determineVisibility();
    
};

}

#endif /* defined(__MVCTemplate__U4DScene__) */
