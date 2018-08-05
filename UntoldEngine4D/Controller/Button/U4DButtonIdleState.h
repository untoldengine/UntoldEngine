//
//  U4DButtonIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonIdleState_hpp
#define U4DButtonIdleState_hpp

#include <stdio.h>

#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DButtonIdleState:public U4DButtonStateInterface {
        
    private:
        
        U4DButtonIdleState();
        
        ~U4DButtonIdleState();
        
    public:
        
        static U4DButtonIdleState* instance;
        
        static U4DButtonIdleState* sharedInstance();
        
        void enter(U4DButton *uButton);
        
        void execute(U4DButton *uButton, double dt);
        
        void exit(U4DButton *uButton);
        
    };
    
}

#endif /* U4DButtonIdleState_hpp */
