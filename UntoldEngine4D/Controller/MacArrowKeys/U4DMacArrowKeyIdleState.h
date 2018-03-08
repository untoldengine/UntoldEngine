//
//  U4DMacArrowKeyIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DMacArrowKeyIdleState_hpp
#define U4DMacArrowKeyIdleState_hpp

#include <stdio.h>
#include "U4DMacArrowKey.h"
#include "U4DMacArrowKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacArrowKeyIdleState:public U4DMacArrowKeyStateInterface {
        
    private:
        
        U4DMacArrowKeyIdleState();
        
        ~U4DMacArrowKeyIdleState();
        
    public:
        
        static U4DMacArrowKeyIdleState* instance;
        
        static U4DMacArrowKeyIdleState* sharedInstance();
        
        void enter(U4DMacArrowKey *uMacArrowKey);
        
        void execute(U4DMacArrowKey *uMacArrowKey, double dt);
        
        void exit(U4DMacArrowKey *uMacArrowKey);
        
    };
    
}
#endif /* U4DMacArrowKeyIdleState_hpp */
