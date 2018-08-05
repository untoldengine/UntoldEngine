//
//  U4DGamepadController.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGamepadController_hpp
#define U4DGamepadController_hpp

#include <stdio.h>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DPadAxis.h"
#include "U4DVector2n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DGamepadController:public U4DControllerInterface{
        
    private:
        
        U4DWorld *gameWorld;
        U4DGameModelInterface *gameModel;
        bool receivedAction;
        
    public:
        //constructor
        U4DGamepadController();
        
        //destructor
        ~U4DGamepadController();
        
        virtual void init(){};
        
        void touchBegan(const U4DTouches &touches){};
        void touchMoved(const U4DTouches &touches){};
        void touchEnded(const U4DTouches &touches){};
        
        void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
        
        void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
        
        void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
        
        /**
         @todo document this
         */
        void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
        
        /**
         @todo document this
         */
        void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){};
        
        /**
         @todo document this
         */
        void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
        
        
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

        void changeState(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
        
        void setGameWorld(U4DWorld *uGameWorld);
        void setGameModel(U4DGameModelInterface *uGameModel);
        
        U4DWorld* getGameWorld();
        U4DGameModelInterface* getGameModel();
        
        void sendUserInputUpdate(void *uData);
        
        void setReceivedAction(bool uValue);
    };
    
}

#endif /* U4DGamepadController_hpp */
