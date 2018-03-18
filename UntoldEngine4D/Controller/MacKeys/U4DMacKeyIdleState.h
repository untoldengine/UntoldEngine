//
//  U4DKeyIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DKeyIdleState_hpp
#define U4DKeyIdleState_hpp

#include <stdio.h>
#include "U4DMacKey.h"
#include "U4DMacKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacKeyIdleState:public U4DMacKeyStateInterface {
        
    private:
        
        U4DMacKeyIdleState();
        
        ~U4DMacKeyIdleState();
        
    public:
        
        static U4DMacKeyIdleState* instance;
        
        static U4DMacKeyIdleState* sharedInstance();
        
        void enter(U4DMacKey *uMacKey);
        
        void execute(U4DMacKey *uMacKey, double dt);
        
        void exit(U4DMacKey *uMacKey);
        
    };
    
}
#endif /* U4DKeyIdleState_hpp */
