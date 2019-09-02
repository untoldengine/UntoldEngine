//
//  U4DMacMouse.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouse_hpp
#define U4DMacMouse_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacMouseStateInterface;
    class U4DMacMouseStateManager;
}

namespace U4DEngine {
    
    class U4DMacMouse:public U4DEntity{
        
    private:
        
        U4DMacMouseStateManager *stateManager;
        
        MOUSEELEMENT padElementType;
        
    public:
        
        U4DMacMouse(MOUSEELEMENT &uMouseElementType);
        
        ~U4DMacMouse();
        
        U4DCallbackInterface *pCallback;
        
        U4DControllerInterface *controllerInterface;
        
        U4DVector3n previousDataPosition;
        
        U4DVector3n dataPosition;
        
        U4DVector2n mouseAxis;
        
        U4DVector2n mouseAxisDelta;
        
        U4DVector2n previousMouseAxisDelta;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(MOUSEACTION &uMouseAction, const U4DVector2n &uMouseAxis);
        
        void setDataPosition(U4DVector3n uData);
        
        U4DVector3n getDataPosition();
        
        U4DVector3n getPreviousDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        U4DVector2n getMouseDeltaPosition();
        
        bool getIsDragged();
        
        void setCallbackAction(U4DCallbackInterface *uAction);
        
        void setControllerInterface(U4DControllerInterface* uControllerInterface);
        
        bool getDirectionReversal();
        
        MOUSEELEMENT getMouseElementType();
        
        bool getIsMoving();
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        U4DMacMouseStateManager *getStateManager();
        
    };
    
}
#endif /* U4DMacMouse_hpp */
