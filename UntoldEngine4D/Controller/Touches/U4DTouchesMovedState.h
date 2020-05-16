//
//  U4DTouchesMovedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesMovedState_hpp
#define U4DTouchesMovedState_hpp

#include <stdio.h>
#include "U4DTouches.h"
#include "U4DTouchesStateInterface.h"

namespace U4DEngine {
    
    class U4DTouchesMovedState:public U4DTouchesStateInterface {
        
    private:
        
        U4DTouchesMovedState();
        
        ~U4DTouchesMovedState();
        
    public:
        
        static U4DTouchesMovedState* instance;
        
        static U4DTouchesMovedState* sharedInstance();
        
        void enter(U4DTouches *uTouches);
        
        void execute(U4DTouches *uTouches, double dt);
        
        void exit(U4DTouches *uTouches);
        
    };
    
}
#endif /* U4DTouchesMovedState_hpp */
