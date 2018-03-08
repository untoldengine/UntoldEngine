//
//  U4DKeyPressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DKeyPressedState_hpp
#define U4DKeyPressedState_hpp

#include <stdio.h>
#include "U4DMacKey.h"
#include "U4DMacKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacKeyPressedState:public U4DMacKeyStateInterface {
        
    private:
        
        U4DMacKeyPressedState();
        
        ~U4DMacKeyPressedState();
        
    public:
        
        static U4DMacKeyPressedState* instance;
        
        static U4DMacKeyPressedState* sharedInstance();
        
        void enter(U4DMacKey *uMacKey);
        
        void execute(U4DMacKey *uMacKey, double dt);
        
        void exit(U4DMacKey *uMacKey);
        
    };
    
}
#endif /* U4DKeyPressedState_hpp */
