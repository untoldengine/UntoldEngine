//
//  U4DTouchesStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesStateManager_hpp
#define U4DTouchesStateManager_hpp

#include <stdio.h>
#include "U4DTouchesStateInterface.h"

class U4DTouches;

namespace U4DEngine {
    
    class U4DTouchesStateManager{
        
    private:
        
        U4DTouches *touches;
        
        U4DTouchesStateInterface *previousState;
        
        U4DTouchesStateInterface *currentState;
        
    public:
        
        U4DTouchesStateManager(U4DTouches *uTouches);
        
        ~U4DTouchesStateManager();
        
        void changeState(U4DTouchesStateInterface *uState);
        
        void update(double dt);
        
        U4DTouchesStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DTouchesStateManager_hpp */
