//
//  U4DPadJoystick.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadJoystick_hpp
#define U4DPadJoystick_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#include "U4DPadAxis.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DPadJoystickStateInterface;
    class U4DPadJoystickStateManager;
}

namespace U4DEngine {
    
    class U4DPadJoystick:public U4DEntity{
        
    private:
        
        U4DPadJoystickStateManager *stateManager;
        
        GAMEPADELEMENT padElementType;
        
    public:
        
        U4DPadJoystick(GAMEPADELEMENT &uPadElementType);
        
        ~U4DPadJoystick();
        
        U4DCallbackInterface *pCallback;
        
        U4DControllerInterface *controllerInterface;
        
        U4DVector3n dataPosition;
        
        U4DPadAxis padAxis;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
        
        void setDataPosition(U4DVector3n uData);
        
        U4DVector3n getDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        bool getIsActive();
        
        void setCallbackAction(U4DCallbackInterface *uAction);
        
        void setControllerInterface(U4DControllerInterface* uControllerInterface);
        
        bool getDirectionReversal();
        
        GAMEPADELEMENT getPadElementType();
    };
    
}
#endif /* U4DPadJoystick_hpp */
