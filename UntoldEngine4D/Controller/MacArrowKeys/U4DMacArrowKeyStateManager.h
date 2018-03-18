//
//  U4DMacArrowKeyStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacArrowKeyStateManager_hpp
#define U4DMacArrowKeyStateManager_hpp

#include <stdio.h>
#include "U4DMacArrowKeyStateInterface.h"

class U4DMacArrowKey;

namespace U4DEngine {
    
    class U4DMacArrowKeyStateManager{
        
    private:
        
        U4DMacArrowKey *padJoystick;
        
        U4DMacArrowKeyStateInterface *previousState;
        
        U4DMacArrowKeyStateInterface *currentState;
        
    public:
        
        U4DMacArrowKeyStateManager(U4DMacArrowKey *uMacArrowKey);
        
        ~U4DMacArrowKeyStateManager();
        
        void changeState(U4DMacArrowKeyStateInterface *uState);
        
        void update(double dt);
        
        U4DMacArrowKeyStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DMacArrowKeyStateManager_hpp */
