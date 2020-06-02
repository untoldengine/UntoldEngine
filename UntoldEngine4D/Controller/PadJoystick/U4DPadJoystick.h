//
//  U4DPadJoystick.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadJoystick_hpp
#define U4DPadJoystick_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DInputElement.h"
#include "CommonProtocols.h"
#include "U4DPadAxis.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DPadJoystickStateInterface;
    class U4DPadJoystickStateManager;
}

namespace U4DEngine {
    
    class U4DPadJoystick:public U4DInputElement{
        
    private:
        
        U4DPadJoystickStateManager *stateManager;
        
    public:
        
        U4DPadJoystick(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        ~U4DPadJoystick();
        
        U4DVector2n dataPosition;
        
        U4DVector2n padAxis;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        void setDataPosition(U4DVector2n &uData);
        
        U4DVector2n getDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        bool getIsActive();
        
        bool getDirectionReversal();
        
    };
    
}
#endif /* U4DPadJoystick_hpp */
