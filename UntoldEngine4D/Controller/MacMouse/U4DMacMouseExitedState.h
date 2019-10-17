//
//  U4DMacMouseExitedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseExitedState_hpp
#define U4DMacMouseExitedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseExitedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseExitedState();
        
        ~U4DMacMouseExitedState();
        
    public:
        
        static U4DMacMouseExitedState* instance;
        
        static U4DMacMouseExitedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseExitedState_hpp */
