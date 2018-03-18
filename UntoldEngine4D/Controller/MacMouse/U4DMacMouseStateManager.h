//
//  U4DMacMouseStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseStateManager_hpp
#define U4DMacMouseStateManager_hpp

#include <stdio.h>
#include "U4DMacMouseStateInterface.h"

class U4DMacMouse;

namespace U4DEngine {
    
    class U4DMacMouseStateManager{
        
    private:
        
        U4DMacMouse *macMouse;
        
        U4DMacMouseStateInterface *previousState;
        
        U4DMacMouseStateInterface *currentState;
        
    public:
        
        U4DMacMouseStateManager(U4DMacMouse *uMacMouse);
        
        ~U4DMacMouseStateManager();
        
        void changeState(U4DMacMouseStateInterface *uState);
        
        void update(double dt);
        
        U4DMacMouseStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DMacMouseStateManager_hpp */
