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
     @brief  Init
     @todo  This method is empty
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
     @todo document this
     */
    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     @todo document this
     */
    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
    
    /**
     @todo document this
     */
    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
    
    /**
     @todo document this
     */
    void setWorld(U4DWorld *uWorld);
    
    /**
     @todo document this
     */
    U4DEntity *searchChild(std::string uName);
    
    //new metal methods
    void setMTLDevice(id <MTLDevice> uMTLDevice);
    
    id <MTLDevice> getMTLDevice();
    
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
    
    void setAspect(float uAspect);
    
    float getAspect();
    
    void setMTLView(MTKView * uMTLView);
    
    MTKView *getMTLView();
    
    void setPerspectiveSpace(U4DMatrix4n &uSpace);
    
    void setOrthographicSpace(U4DMatrix4n &uSpace);
    
    void setOrthographicShadowSpace(U4DMatrix4n &uSpace);
    
    U4DMatrix4n getPerspectiveSpace();
    
    U4DMatrix4n getOrthographicSpace();
    
    U4DMatrix4n getOrthographicShadowSpace();
    
    U4DMatrix4n computePerspectiveSpace(float fov, float aspect, float near, float far);
    
    U4DMatrix4n computeOrthographicSpace(float left, float right, float bottom, float top, float near, float far);
    
    U4DMatrix4n computeOrthographicShadowSpace(float left, float right, float bottom, float top, float near, float far);

    void determineVisibility();
    
    void setShadowBiasDepth(float uValue);
    
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
     @brief document this
     */
    void setDeviceOSType(DEVICEOSTYPE &uDeviceOSType);
    
    /**
     @brief document this
     */
    DEVICEOSTYPE getDeviceOSType();
    
};

}

#endif /* defined(__MVCTemplate__U4DDirector__) */
