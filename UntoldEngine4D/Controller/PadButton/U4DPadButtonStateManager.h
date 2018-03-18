//
//  U4DPadButtonStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadButtonStateManager_hpp
#define U4DPadButtonStateManager_hpp

#include <stdio.h>
#include "U4DPadButtonStateInterface.h"

class U4DPadButton;

namespace U4DEngine {
    
    class U4DPadButtonStateManager{
        
    private:
        
        U4DPadButton *padButton;
        
        U4DPadButtonStateInterface *previousState;
        
        U4DPadButtonStateInterface *currentState;
        
    public:
        
        U4DPadButtonStateManager(U4DPadButton *uPadButton);
        
        ~U4DPadButtonStateManager();
        
        void changeState(U4DPadButtonStateInterface *uState);
        
        void update(double dt);
        
        U4DPadButtonStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DPadButtonStateManager_hpp */
