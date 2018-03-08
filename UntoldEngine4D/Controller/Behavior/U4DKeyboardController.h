//
//  U4DKeyboardInput.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DKeyboardInput__
#define __MVCTemplate__U4DKeyboardInput__

#include <iostream>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DKeyboardController:public U4DControllerInterface{
        
    private:
        
        U4DWorld *gameWorld;
        U4DGameModelInterface *gameModel;
        bool receivedAction;
        
    public:
        //constructor
        U4DKeyboardController();
        
        //destructor
        ~U4DKeyboardController();
        
        virtual void init(){};
        
        
        void touchBegan(const U4DTouches &touches){};
        void touchMoved(const U4DTouches &touches){};
        void touchEnded(const U4DTouches &touches){};
        void changeState(const U4DTouches &touches,TOUCHSTATE touchState){};
        
        
        /**
         @todo document this
         */
        void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
        
        /**
         @todo document this
         */
        void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
        
        /**
         @todo document this
         */
        void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){};
        
        
        void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
        
        void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
        
        /**
         @todo document this
         */
        void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
        
        void changeState(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
        
        
        
        
        void setGameWorld(U4DWorld *uGameWorld);
        void setGameModel(U4DGameModelInterface *uGameModel);
        
        U4DWorld* getGameWorld();
        U4DGameModelInterface* getGameModel();
        
        void sendUserInputUpdate(void *uData);
        
        void setReceivedAction(bool uValue);
    };
    
}

#endif /* defined(__MVCTemplate__U4DKeyboardInput__) */
