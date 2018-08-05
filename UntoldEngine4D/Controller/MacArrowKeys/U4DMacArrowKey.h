//
//  U4DMacArrowKey.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacArrowKey_hpp
#define U4DMacArrowKey_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacArrowKeyStateInterface;
    class U4DMacArrowKeyStateManager;
}

namespace U4DEngine {
    
    class U4DMacArrowKey:public U4DEntity{
        
    private:
        
        U4DMacArrowKeyStateManager *stateManager;
        
        KEYBOARDELEMENT padElementType;
        
    public:
        
        U4DMacArrowKey(KEYBOARDELEMENT &uPadElementType);
        
        ~U4DMacArrowKey();
        
        U4DCallbackInterface *pCallback;
        
        U4DControllerInterface *controllerInterface;
        
        U4DVector3n dataPosition;
        
        U4DVector2n padAxis;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(KEYBOARDACTION &uKeyboardAction, const U4DVector2n &uPadAxis);
        
        void setDataPosition(U4DVector3n uData);
        
        U4DVector3n getDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        bool getIsActive();
        
        void setCallbackAction(U4DCallbackInterface *uAction);
        
        void setControllerInterface(U4DControllerInterface* uControllerInterface);
        
        bool getDirectionReversal();
        
        KEYBOARDELEMENT getKeyboardElementType();
    };
    
}
#endif /* U4DMacArrowKey_hpp */
