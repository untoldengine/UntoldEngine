//
//  U4DButton.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DButton__
#define __UntoldEngine__U4DButton__

#include <iostream>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DMultiImage.h"
#include "U4DTouches.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DImage;
}

namespace U4DEngine {
class U4DButton:public U4DEntity{
  
private:
    
    TouchState buttonState;
    TouchState buttonActionOn;
    U4DCallbackInterface *pCallback;
    
    float left,right,bottom,top;
    U4DVector3n centerPosition;
    
    U4DMultiImage buttonImages;

public:
    
    U4DButton(float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2,U4DCallbackInterface *uAction,TouchState uButtonActionOn);
    
    void draw();
    void update(float dt);
    void action();
    void setButtonActionOn(TouchState &uButtonActionOn);
    TouchState getButtonActionOn();
    

    void changeState(TouchState uTouchState,U4DVector3n uTouchPosition);
    void changeState(TouchState uTouchState);
    TouchState getState();
};

}

#endif /* defined(__UntoldEngine__U4DButton__) */
