//
//  U4DKeyReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DKeyReleasedState_hpp
#define U4DKeyReleasedState_hpp

#include <stdio.h>
#include "U4DMacKey.h"
#include "U4DMacKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacKeyReleasedState:public U4DMacKeyStateInterface {
        
    private:
        
        U4DMacKeyReleasedState();
        
        ~U4DMacKeyReleasedState();
        
    public:
        
        static U4DMacKeyReleasedState* instance;
        
        static U4DMacKeyReleasedState* sharedInstance();
        
        void enter(U4DMacKey *uMacKey);
        
        void execute(U4DMacKey *uMacKey, double dt);
        
        void exit(U4DMacKey *uMacKey);
        
    };
    
}
#endif /* U4DKeyReleasedState_hpp */
