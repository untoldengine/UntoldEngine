//
//  U4DMacMouseDeltaMovedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseDeltaMovedState_hpp
#define U4DMacMouseDeltaMovedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseDeltaMovedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseDeltaMovedState();
        
        ~U4DMacMouseDeltaMovedState();
        
        U4DVector2n motionDeltaAccumulator;
        
        float mouseSlowFactor;
        
    public:
        
        static U4DMacMouseDeltaMovedState* instance;
        
        static U4DMacMouseDeltaMovedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseDeltaMovedState_hpp */
