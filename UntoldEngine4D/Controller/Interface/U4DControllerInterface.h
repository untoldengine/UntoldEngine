//
//  U4DControllerInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DControllerInterface__
#define __UntoldEngine__U4DControllerInterface__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DTouches;
    class U4DButton;
    class U4DJoyStick;
    class U4DWorld;
    class U4DVector2n;
    class U4DGameModelInterface;
    class U4DPadAxis;
}

namespace U4DEngine {
    
class U4DControllerInterface{
  
private:
    
    
public:
    
    virtual ~U4DControllerInterface(){};
    
    virtual void touchBegan(const U4DTouches &touches)=0;
    virtual void touchMoved(const U4DTouches &touches)=0;
    virtual void touchEnded(const U4DTouches &touches)=0;
    
    /**
     @todo document this
     */
    virtual void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction)=0;
    
    /**
     @todo document this
     */
    virtual void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction)=0;
    
    /**
     @todo document this
     */
    virtual void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis)=0;
    
    virtual void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction)=0;
    
    virtual void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction)=0;
    
    virtual void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis)=0;
    
    virtual void changeState(const U4DTouches &touches,TOUCHSTATE touchState)=0;
    
    virtual void init()=0;
    
    virtual void setGameWorld(U4DWorld *uGameWorld)=0;
    virtual void setGameModel(U4DGameModelInterface *uGameModel)=0;
    
    virtual U4DWorld* getGameWorld()=0;
    virtual U4DGameModelInterface* getGameModel()=0;
    
    virtual void setReceivedAction(bool uValue)=0;
    virtual void sendUserInputUpdate(void *uData)=0;
};

}
#endif /* defined(__UntoldEngine__U4DControllerInterface__) */
