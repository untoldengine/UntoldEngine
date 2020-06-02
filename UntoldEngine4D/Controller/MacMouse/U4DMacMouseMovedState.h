//
//  U4DMacMouseMovedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseMovedState_hpp
#define U4DMacMouseMovedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseMovedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseMovedState();
        
        ~U4DMacMouseMovedState();
        
        U4DVector2n motionAccumulator;
        
    public:
        
        static U4DMacMouseMovedState* instance;
        
        static U4DMacMouseMovedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseMovedState_hpp */
