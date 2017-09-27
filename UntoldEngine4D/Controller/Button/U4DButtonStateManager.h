//
//  U4DButtonStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DButtonStateManager_hpp
#define U4DButtonStateManager_hpp

#include <stdio.h>
#include "U4DButtonStateInterface.h"

class U4DButton;

namespace U4DEngine {
    
    class U4DButtonStateManager{
        
    private:
        
        U4DButton *button;
        
        U4DButtonStateInterface *previousState;

        U4DButtonStateInterface *currentState;
        
    public:
        
        U4DButtonStateManager(U4DButton *uButton);
        
        ~U4DButtonStateManager();
        
        void changeState(U4DButtonStateInterface *uState);
        
        void update(double dt);
        
        U4DButtonStateInterface *getCurrentState();
        
    };
    
}

#endif /* U4DButtonStateManager_hpp */
