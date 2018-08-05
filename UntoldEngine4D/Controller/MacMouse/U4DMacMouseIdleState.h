//
//  U4DMacMouseIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseIdleState_hpp
#define U4DMacMouseIdleState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseIdleState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseIdleState();
        
        ~U4DMacMouseIdleState();
        
    public:
        
        static U4DMacMouseIdleState* instance;
        
        static U4DMacMouseIdleState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseIdleState_hpp */
