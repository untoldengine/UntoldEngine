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
#include "U4DInputElement.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacMouseStateInterface;
    class U4DMacMouseStateManager;
}

namespace U4DEngine {
    
    class U4DMacMouse:public U4DInputElement{
        
    private:
        
        U4DMacMouseStateManager *stateManager;
                
    public:
        
        U4DMacMouse(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        ~U4DMacMouse();
        
        U4DVector2n previousDataPosition;
        
        U4DVector2n dataPosition;
        
        U4DVector2n dataDeltaPosition;
        
        U4DVector2n previousDataDeltaPosition;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        void setDataPosition(U4DVector2n uData);
        
        U4DVector2n getDataPosition();
        
        U4DVector2n getPreviousDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        U4DVector2n getDataDeltaPosition();
        
        bool getIsDragged();
        
        bool getDirectionReversal();
        
        bool getIsMoving();
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        U4DMacMouseStateManager *getStateManager();
        
        U4DVector2n mapMousePosition(U4DVector2n &uPosition);
        
    };
    
}
#endif /* U4DMacMouse_hpp */
