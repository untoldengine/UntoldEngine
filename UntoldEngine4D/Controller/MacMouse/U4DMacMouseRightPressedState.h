//
//  U4DMacMouseRightPressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseRightPressedState_hpp
#define U4DMacMouseRightPressedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseRightPressedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseRightPressedState();
        
        ~U4DMacMouseRightPressedState();
        
    public:
        
        static U4DMacMouseRightPressedState* instance;
        
        static U4DMacMouseRightPressedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseRightPressedState_hpp */
