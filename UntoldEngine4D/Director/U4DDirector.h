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
    class U4DGameModelInterface;
    class U4DVector2n;
    class U4DControllerInterface;
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
    
    float fps;
    
    float fpsAccumulator;
    
    U4DMatrix4n perspectiveSpace;
    
    U4DMatrix4n orthographicSpace;
    
    U4DMatrix4n orthographicShadowSpace;
    
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
     @brief sets the fps
     */
    void setFPS(float uFPS);
    
    /*
     @brief getFPS();
     */
    float getFPS();
    
};

}

#endif /* defined(__MVCTemplate__U4DDirector__) */
