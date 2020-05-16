//
//  Touches.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouches__
#define __UntoldEngine__U4DTouches__

#include <iostream>
#include "U4DInputElement.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DTouchesStateInterface;
    class U4DTouchesStateManager;
}

namespace U4DEngine {


    class U4DTouches:public U4DInputElement{
      
    private:
        
        U4DTouchesStateManager *stateManager;
        
        U4DVector2n dataPosition;
        
    public:

        /**
         @brief Touch constructor
         */
        U4DTouches(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        /**
         @brief Touch destructor
         */
        ~U4DTouches();
        
        void setDataPosition(U4DVector2n uDataPosition);
        
        U4DVector2n getDataPosition();
        
        void update(double dt);
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        void action();
        
        bool getIsMoving();
        
        bool getIsPressed();
        
        bool getIsReleased();
        
    };
    
}

#endif /* defined(__UntoldEngine__Touches__) */
