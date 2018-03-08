//
//  U4DKeyStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DKeyStateManager_hpp
#define U4DKeyStateManager_hpp

#include <stdio.h>
#include "U4DMacKeyStateInterface.h"

class U4DMacKey;

namespace U4DEngine {
    
    class U4DMacKeyStateManager{
        
    private:
        
        U4DMacKey *macKey;
        
        U4DMacKeyStateInterface *previousState;
        
        U4DMacKeyStateInterface *currentState;
        
    public:
        
        U4DMacKeyStateManager(U4DMacKey *uMacKey);
        
        ~U4DMacKeyStateManager();
        
        void changeState(U4DMacKeyStateInterface *uState);
        
        void update(double dt);
        
        U4DMacKeyStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DKeyStateManager_hpp */
