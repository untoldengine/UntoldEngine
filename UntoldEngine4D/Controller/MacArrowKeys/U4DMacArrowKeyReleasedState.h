//
//  U4DMacArrowKeyReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacArrowKeyReleasedState_hpp
#define U4DMacArrowKeyReleasedState_hpp

#include <stdio.h>
#include "U4DMacArrowKey.h"
#include "U4DMacArrowKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacArrowKeyReleasedState:public U4DMacArrowKeyStateInterface {
        
    private:
        
        U4DMacArrowKeyReleasedState();
        
        ~U4DMacArrowKeyReleasedState();
        
    public:
        
        static U4DMacArrowKeyReleasedState* instance;
        
        static U4DMacArrowKeyReleasedState* sharedInstance();
        
        void enter(U4DMacArrowKey *uMacArrowKey);
        
        void execute(U4DMacArrowKey *uMacArrowKey, double dt);
        
        void exit(U4DMacArrowKey *uMacArrowKey);
        
    };
    
}
#endif /* U4DMacArrowKeyReleasedState_hpp */
