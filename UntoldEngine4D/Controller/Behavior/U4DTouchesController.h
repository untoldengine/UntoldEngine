//
//  U4DTouchesController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouchesController__
#define __UntoldEngine__U4DTouchesController__

#include <iostream>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
class U4DWorld;
class U4DGameModelInterface;
class U4DTouches;
class U4DButton;
class U4DJoyStick;
class U4DImage;
class U4DVector2n;
}

namespace U4DEngine {
    
class U4DTouchesController:public U4DControllerInterface{
  
private:
    
    U4DWorld *gameWorld;
    U4DGameModelInterface *gameModel;
    bool receivedAction;
    
public:
    //constructor
    U4DTouchesController();
    
    //destructor
    ~U4DTouchesController();

    virtual void init(){};
    
    void touchBegan(const U4DTouches &touches);
    void touchMoved(const U4DTouches &touches);
    void touchEnded(const U4DTouches &touches);
    
    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){};
    
    void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
    
    void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
    
    void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
    
    void changeState(const U4DTouches &touches,TOUCHSTATE touchState);
    
    void setGameWorld(U4DWorld *uGameWorld);
    void setGameModel(U4DGameModelInterface *uGameModel);
    
    U4DWorld* getGameWorld();
    U4DGameModelInterface* getGameModel();
    
    void sendUserInputUpdate(void *uData);
    
    void setReceivedAction(bool uValue);
};

}

#endif /* defined(__UntoldEngine__U4DTouchesController__) */
