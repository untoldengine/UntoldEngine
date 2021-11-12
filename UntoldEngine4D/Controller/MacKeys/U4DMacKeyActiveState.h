//
//  U4DMacKeyActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/12/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacKeyActiveState_hpp
#define U4DMacKeyActiveState_hpp

#include <stdio.h>
#include "U4DMacKey.h"
#include "U4DMacKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacKeyActiveState:public U4DMacKeyStateInterface {
        
    private:
        
        U4DMacKeyActiveState();
        
        ~U4DMacKeyActiveState();
        
    public:
        
        static U4DMacKeyActiveState* instance;
        
        static U4DMacKeyActiveState* sharedInstance();
        
        void enter(U4DMacKey *uMacKey);
        
        void execute(U4DMacKey *uMacKey, double dt);
        
        void exit(U4DMacKey *uMacKey);
        
    };
    
}
#endif /* U4DMacKeyActiveState_hpp */
