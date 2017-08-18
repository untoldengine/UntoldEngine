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
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    class U4DImage;
    class U4DControllerInterface;
    class U4DButtonStateManager;
    class U4DButtonStateInterface;
}

namespace U4DEngine {
class U4DButton:public U4DEntity{
  
private:
    
    U4DButtonStateManager *stateManager;
    
    float left,right,bottom,top;
    
    U4DVector3n centerPosition;
    
    U4DVector3n currentTouchPosition;
    

public:
    
    U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2);
    
    ~U4DButton();
    
    U4DCallbackInterface *pCallback;
    
    U4DControllerInterface *controllerInterface;
    
    U4DMultiImage buttonImages;
    
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    void update(double dt);
    
    void action();

    void changeState(TOUCHSTATE uTouchState,U4DVector3n uTouchPosition);
    
    bool getIsPressed();
    
    bool getIsReleased();
    
    void setCallbackAction(U4DCallbackInterface *uAction);
    
    void setControllerInterface(U4DControllerInterface* uControllerInterface);
};

}

#endif /* defined(__UntoldEngine__U4DButton__) */
