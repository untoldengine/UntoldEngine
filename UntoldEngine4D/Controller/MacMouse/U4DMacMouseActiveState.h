//
//  U4DMacMouseActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DMacMouseActiveState_hpp
#define U4DMacMouseActiveState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseActiveState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseActiveState();
        
        ~U4DMacMouseActiveState();
        
    public:
        
        static U4DMacMouseActiveState* instance;
        
        static U4DMacMouseActiveState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseActiveState_hpp */
