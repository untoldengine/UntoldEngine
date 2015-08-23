//
//  U4DJoyStick.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DJoyStick__
#define __UntoldEngine__U4DJoyStick__

#include <iostream>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DImage.h"
#include "U4DTouches.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DJoyStick:public U4DEntity{
  
private:
    U4DCallbackInterface *pCallback;
    
    float backgroundWidth;
    float backgroundHeight;
    
    float joyStickWidth;
    float joyStickHeight;
    
    U4DVector3n originalPosition;
    TouchState joyStickState;
    
    U4DVector3n dataPosition;
    float dataMagnitude;
    
    U4DVector3n currentPosition;
    
    U4DVector3n centerBackgroundPosition;
    U4DVector3n centerImagePosition;
    
    float backgroundImageRadius;
    float joyStickImageRadius;
    
    
public:
    
    U4DImage backgroundImage;
    U4DImage joyStickImage;
    
    U4DJoyStick(float xPosition,float yPosition,const char* uBackGroundImage,float uBackgroundWidth,float uBackgroundHeight,const char* uJoyStickImage,float uJoyStickWidth,float uJoyStickHeight,U4DCallbackInterface *uAction):joyStickState(rTouchesNull){
    
        
        joyStickWidth=uJoyStickWidth;
        joyStickHeight=uJoyStickHeight;
        
        //copy the width and height of the image to the button
        backgroundWidth=uBackgroundWidth;
        backgroundHeight=uBackgroundHeight;
        
        
        backgroundImage.setImage(uBackGroundImage,uBackgroundWidth,uBackgroundHeight);
        
        
        U4DVector3n translation(xPosition,yPosition,0.0);
        translateTo(translation);     //move the joyStick
        
        
        backgroundImage.translateTo(translation);  //move the image
        
        //add the joy stick
        joyStickImage.setImage(uJoyStickImage,uJoyStickWidth,uJoyStickHeight);
        joyStickImage.translateTo(translation);
        
        
        //set the callback
        pCallback=uAction;
        
        //get the original center position of the joystick
        originalPosition=getLocalPosition();
        
        
        //get the coordinates of the box
        centerBackgroundPosition=backgroundImage.getLocalPosition();
        centerImagePosition=getLocalPosition();
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        backgroundImageRadius=getJoyStickBackgroundWidth()/director->getDisplayWidth();;
        joyStickImageRadius=getJoyStickWidth()/director->getDisplayWidth();
        

    };
    
    ~U4DJoyStick(){};
    
    void draw();
    void update(float dt);
    void action();
    
    inline void setJoyStickWidth(float uJoyStickWidth){ joyStickWidth=uJoyStickWidth;};
    inline void setJoyStickHeight(float uJoyStickHeight){joyStickHeight=uJoyStickHeight;};
    inline float getJoyStickWidth(){return joyStickWidth;};
    inline float getJoyStickHeight(){return joyStickHeight;};
    
    
    void setJoyStickBackgroundWidth(float uJoyStickBackgroundWidth){backgroundWidth=uJoyStickBackgroundWidth;};
    void setJoyStickBackgroundHeight(float uJoyStickBackgroundHeight){backgroundHeight=uJoyStickBackgroundHeight;};
    inline float getJoyStickBackgroundWidth(){return backgroundWidth;};
    inline float getJoyStickBackgroundHeight(){return backgroundHeight;};
    
    void changeState(TouchState uTouchState,U4DVector3n uNewPosition);
    void changeState(TouchState uTouchState);
    TouchState getState();
    
    void setDataPosition(U4DVector3n uData);
    U4DVector3n getDataPosition();
    
    inline void setDataMagnitude(float uValue){dataMagnitude=uValue;};
    inline float getDataMagnitude(){return dataMagnitude;};
};

}

#endif /* defined(__UntoldEngine__U4DJoyStick__) */
