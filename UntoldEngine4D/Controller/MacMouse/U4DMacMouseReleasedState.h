//
//  U4DMacMouseReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseReleasedState_hpp
#define U4DMacMouseReleasedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseReleasedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseReleasedState();
        
        ~U4DMacMouseReleasedState();
        
    public:
        
        static U4DMacMouseReleasedState* instance;
        
        static U4DMacMouseReleasedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseReleasedState_hpp */
