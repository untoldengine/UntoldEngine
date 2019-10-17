//
//  U4DDirector.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DDirector__
#define __MVCTemplate__U4DDirector__


#include <iostream>
#include <vector>
#include <iterator>
#include "CommonProtocols.h"
#include "U4DMatrix4n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DScene;
    class U4DWorld;
    class U4DCharacterManager;
    class U4DData;
    class U4DTouches;
    class U4DGameModelInterface;
    class U4DVector2n;
    class U4DControllerInterface;
    class U4DTouches;
    class U4DEntityManager;
    class U4DPadAxis;
}

namespace U4DEngine {
    
/**
 @brief  The U4DDirector class controls the updates and rendering of every game entity. It informs the engine of any touch event. It loads every shader used in the engine.
 */

class U4DDirector{
  
private:
    
    id <MTLDevice> mtlDevice;
    
    MTKView * mtlView;
    
    float aspect;
    
    U4DMatrix4n perspectiveSpace;
    
    U4DMatrix4n orthographicSpace;
    
    U4DMatrix4n orthographicShadowSpace;
    
    /**
     @brief Pointer representing the scene of the game
     */
    U4DScene *scene;
    
    /**
     @brief ios device display width
     */
    float displayWidth;
    
    /**
     @brief ios device display height
     */
    float displayHeight;
    
    /**
     @brief Time step accumulator
     */
    float accumulator;
    
    /**
     @brief number of polygons the engine can render. Default value is 3000
     */
    int polycount;
    
    /**
     @brief shadow bias depth to prevent shadow acne
    */
    float shadowBiasDepth;
    
    /**
     @todo document this
     */
    U4DWorld *world;
    
    /**
     @todo document this
     */
    DEVICEOSTYPE deviceOSType;
    
    /**
     @todo document this
     */
    bool gamePadControllerPresent;
    
    /**
     @todo document this
     */
    bool modelsWithinFrustum;
    
    /**
     @todo document this.
     */
    float screenScaleFactor;
    
    /**
     @brief global time since game started
     */
    float globalTime;
    
protected:
    
    /**
     @brief Director Constructor
     */
    U4DDirector();
    
    /**
     @brief Director Destructor
     */
    ~U4DDirector();
    
    /**
     @brief Copy constructor
     */
    U4DDirector(const U4DDirector& value);

    /**
     @brief Copy constructor
     */
    U4DDirector& operator=(const U4DDirector& value);
    
public:
    
    /**
     @brief Instance for U4DDirector Singleton
     */
    static U4DDirector* instance;
    
    /**
     @brief Method which returns an instance of the U4DDirector singleton
     
     @return instance of the U4DDirector singleton
     */
    static U4DDirector* sharedInstance();
    
    /**
     @brief Method in charge of updating the states of each entity
     
     @param dt time value
     */
    void update(double dt);
    
    /**
     @brief init method.
     */
    void init();
    
    /**
     @brief Method which sets the active scene for the game
     
     @param uScene Pointer to the scene to make active
     */
    void setScene(U4DScene *uScene);
    
    /**
     @brief Method which sets the dimension of the display screen
     
     @param uWidth  display width
     @param uHeight display height
     */
    void setDisplayWidthHeight(float uWidth,float uHeight);
   
    /**
     @brief Method which returns the height of the display screen
     
     @return Returns the height of the display screen
     */
    float getDisplayHeight();
    
    /**
     @brief Method which returns the width of the display screen
     
     @return Returns the width of the display screen
     */
    float getDisplayWidth();
    
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
     * @brief The mouse key is being dragged
     * @details The engine has detected mouse drag-movement
     *
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
     */
    void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     * @brief The mouse cursor is being moved
     * @details The engine has detected mouse movement
     *
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
     */
    void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     * @brief The mouse cursor is being moved and gets its delta movement
     * @details The engine has detected mouse movement
     *
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseDelta Delta movement direction in a 2D vector format.
     */
    void macMouseDeltaMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseDelta);
    
    /**
     * @brief The mouse cursor exited the window
     * @details The engine has detected mouse exit-movement
     *
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
     */
    void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
    
    /**
     @todo document this. It seems that this method is not longer used. Check if it should be removed
     */
    void setWorld(U4DWorld *uWorld);
    
    /**
     @todo document this. It seems that this method is not longer used. Check if it should be removed
     */
    U4DEntity *searchChild(std::string uName);
    
    //new metal methods
    
    /**
     @brief Set the device required for Metal

     @param uMTLDevice pointer to the device
     */
    void setMTLDevice(id <MTLDevice> uMTLDevice);
    
    
    /**
     @brief Gets the metal device

     @return pointer to the metal device
     */
    id <MTLDevice> getMTLDevice();
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    /**
     * @brief Renders the shadow for a 3D entity
     * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
     *
     * @param uShadowTexture Texture shadow for the current entity
     */
    void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
    
    
    /**
     @brief Sets the view aspect ratio for the window

     @param uAspect window aspect ratio
     */
    void setAspect(float uAspect);
    
    
    /**
     @brief Gets the window aspect ratio

     @return window aspect ratio
     */
    float getAspect();
    
    
    /**
     @brief Set the Metal View

     @param uMTLView pointer to the Metal view
     */
    void setMTLView(MTKView * uMTLView);
    
    
    /**
     @brief Gets the Metal View

     @return pointer to the Metal view
     */
    MTKView *getMTLView();
    
    
    /**
     @brief Set the perspective projection for the view

     @param uSpace perspective projection in a 4x4 matrix
     */
    void setPerspectiveSpace(U4DMatrix4n &uSpace);
    
    
    /**
     @brief Set the orthographic projection for the view

     @param uSpace orthographic projection in a 4x4 matrix
     */
    void setOrthographicSpace(U4DMatrix4n &uSpace);
    
    
    /**
     @brief Set the orthographic projection for the shadow space

     @param uSpace orthographic projection (4x4 matrix) for the shadow
     */
    void setOrthographicShadowSpace(U4DMatrix4n &uSpace);
    
    
    /**
     @brief Get the perspective space of the view

     @return perspective space of the view in a 4x4 matrix
     */
    U4DMatrix4n getPerspectiveSpace();
    
    /**
     @brief Get the orthographics space of the view

     @return Orthographic space of the view in a 4x4 matrix
     */
    U4DMatrix4n getOrthographicSpace();
    
    /**
     @brief Get the orthographic space of the shadow

     @return Orthographic space of the shadow in a 4x4 matrix
     */
    U4DMatrix4n getOrthographicShadowSpace();
    
    
    /**
     @brief Computes the perspective space of the view

     @param fov Field of view in degrees
     @param aspect Aspect ratio of the view window
     @param near Near plane
     @param far Far plane
     @return A 4x4 matrix representing the perspective view
     */
    U4DMatrix4n computePerspectiveSpace(float fov, float aspect, float near, float far);
    
    /**
     @brief Computes the orthographic space of the view

     @param left left plane
     @param right right plane
     @param bottom bottom plane
     @param top top plane
     @param near near plane
     @param far far plane
     @return A 4x4 matrix representing the orthographic view
     */
    U4DMatrix4n computeOrthographicSpace(float left, float right, float bottom, float top, float near, float far);
    
    /**
     @brief Computes the orthographic space of the shadow
     
     @param left left plane
     @param right right plane
     @param bottom bottom plane
     @param top top plane
     @param near near plane
     @param far far plane
     @return A 4x4 matrix representing the orthographic view
     */
    U4DMatrix4n computeOrthographicShadowSpace(float left, float right, float bottom, float top, float near, float far);

    /**
     @brief Determines if the 3D models are within the camera frustum
     */
    void determineVisibility();
    
    
    /**
     @brief Sets the bias depth for shadow rendering

     @param uValue bias depth
     */
    void setShadowBiasDepth(float uValue);
    
    
    /**
     @brief Gets the shadow depth bias

     @return Shadow depth bias
     */
    float getShadowBiasDepth();
    
    /**
     @brief sets the number of polygons the engien can render per 3d model. It is recommended to set this value as low as possible. Suggested and default value is 3000

     @param uValue value representing the polycount
     */
    void setPolycount(int uValue);
    
    /**
     @brief returns the number of polygons the engine can render per 3d model

     @return Number of polys
     */
    int getPolycount();
    
    
    /**
     @brief Sets the current Device OS type. e.g., iOS or mac

     @param uDeviceOSType enum to the device type
     */
    void setDeviceOSType(DEVICEOSTYPE &uDeviceOSType);
    
    
    /**
     @brief Get the current device OS type. e.g, iOS or mac

     @return enum to device OS type.
     */
    DEVICEOSTYPE getDeviceOSType();
    
    
    /**
     @brief Sets the presence of a game pad controller

     @param uValue Set it to true if you wans to use the Game Pad Controller. False otherwise.
     */
    void setGamePadControllerPresent(bool uValue);
    
    
    /**
     @brief Gets if the presence of the game pad controller

     @return true if the user selected the Game pad controller
     */
    bool getGamePadControllerPresent();
    
    
    /**
     @brief This method is set if any model, at least one, is within the camera frustum

     @param uValue true if a 3D model is within the camera frustum
     */
    void setModelsWithinFrustum(bool uValue);
    
    
    /**
     @brief Gets if any 3D model is within the camera frustum

     @return true if a 3D model is within the camera frustum
     */
    bool getModelsWithinFrustum();
    
    /**
     @todo document this
     */
    void setScreenScaleFactor(float uScreenScaleFactor);
    
    /**
     @todo document this
     */
    float getScreenScaleFactor();
    
    /**
     @brief Returns the global time
     
     @return The global time since the game started. Mainly used for the shaders
     */
    float getGlobalTime();
    
};

}

#endif /* defined(__MVCTemplate__U4DDirector__) */
