//
//  U4DMacMousePressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DMacMousePressedState_hpp
#define U4DMacMousePressedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMousePressedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMousePressedState();
        
        ~U4DMacMousePressedState();
        
    public:
        
        static U4DMacMousePressedState* instance;
        
        static U4DMacMousePressedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMousePressedState_hpp */
