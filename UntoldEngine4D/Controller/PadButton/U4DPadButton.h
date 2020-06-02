//
//  U4DPadButton.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadButton_hpp
#define U4DPadButton_hpp

#include <stdio.h>
#include <vector>
#include "U4DInputElement.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DPadButtonStateManager;
    class U4DPadButtonStateInterface;
}

namespace U4DEngine {

    class U4DPadButton:public U4DInputElement{
        
    private:
        
        U4DPadButtonStateManager *stateManager;
        
    public:
        
        U4DPadButton(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        ~U4DPadButton();
        
        void update(double dt);
        
        void action();
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        
    };
    
}

#endif /* U4DPadButton_hpp */
