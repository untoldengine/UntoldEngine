//
//  U4DMacMouseRightReleaseState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseRightReleaseState_hpp
#define U4DMacMouseRightReleaseState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseRightReleasedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseRightReleasedState();
        
        ~U4DMacMouseRightReleasedState();
        
    public:
        
        static U4DMacMouseRightReleasedState* instance;
        
        static U4DMacMouseRightReleasedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseRightReleaseState_hpp */
