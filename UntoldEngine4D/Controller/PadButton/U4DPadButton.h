//
//  U4DPadButton.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadButton_hpp
#define U4DPadButton_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DPadAxis.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DPadButtonStateManager;
    class U4DPadButtonStateInterface;
}

namespace U4DEngine {
    class U4DPadButton:public U4DEntity{
        
    private:
        
        U4DPadButtonStateManager *stateManager;
        
        GAMEPADELEMENT padElementType;
        
    public:
        
        U4DPadButton(GAMEPADELEMENT &uPadElementType);
        
        ~U4DPadButton();
        
        U4DCallbackInterface *pCallback;
        
        U4DControllerInterface *controllerInterface;
        
        void update(double dt);
        
        void action();
        
        void changeState(GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        GAMEPADELEMENT getPadElementType();
        
        void setCallbackAction(U4DCallbackInterface *uAction);
        
        void setControllerInterface(U4DControllerInterface* uControllerInterface);
    };
    
}

#endif /* U4DPadButton_hpp */
