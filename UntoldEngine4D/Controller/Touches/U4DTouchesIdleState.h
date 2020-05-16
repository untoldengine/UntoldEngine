//
//  U4DTouchesIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesIdleState_hpp
#define U4DTouchesIdleState_hpp

#include <stdio.h>
#include "U4DTouches.h"
#include "U4DTouchesStateInterface.h"

namespace U4DEngine {
    
    class U4DTouchesIdleState:public U4DTouchesStateInterface {
        
    private:
        
        U4DTouchesIdleState();
        
        ~U4DTouchesIdleState();
        
    public:
        
        static U4DTouchesIdleState* instance;
        
        static U4DTouchesIdleState* sharedInstance();
        
        void enter(U4DTouches *uTouches);
        
        void execute(U4DTouches *uTouches, double dt);
        
        void exit(U4DTouches *uTouches);
        
    };
    
}
#endif /* U4DTouchesIdleState_hpp */
