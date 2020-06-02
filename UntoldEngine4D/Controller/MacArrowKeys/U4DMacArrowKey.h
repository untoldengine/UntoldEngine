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
#include "U4DCallbackInterface.h"
#include "U4DInputElement.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacArrowKeyStateInterface;
    class U4DMacArrowKeyStateManager;
}

namespace U4DEngine {
    
class U4DMacArrowKey:public U4DInputElement{
        
    private:
        
        U4DMacArrowKeyStateManager *stateManager;
        
    public:
        
        U4DMacArrowKey(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        ~U4DMacArrowKey();
        
        U4DVector2n dataPosition;
        
        U4DVector2n padAxis;
        
        float dataMagnitude;
        
        bool isActive;
        
        bool directionReversal;
        
        void update(double dt);
        
        void action();
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        void setDataPosition(U4DVector2n uData);
        
        U4DVector2n getDataPosition();
        
        void setDataMagnitude(float uValue);
        
        float getDataMagnitude();
        
        bool getIsActive();
        
        bool getDirectionReversal();
        
    };
    
}
#endif /* U4DMacArrowKey_hpp */
