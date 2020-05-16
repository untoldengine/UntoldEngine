//
//  U4DTouchesReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesReleasedState_hpp
#define U4DTouchesReleasedState_hpp

#include <stdio.h>
#include "U4DTouches.h"
#include "U4DTouchesStateInterface.h"

namespace U4DEngine {
    
    class U4DTouchesReleasedState:public U4DTouchesStateInterface {
        
    private:
        
        U4DTouchesReleasedState();
        
        ~U4DTouchesReleasedState();
        
    public:
        
        static U4DTouchesReleasedState* instance;
        
        static U4DTouchesReleasedState* sharedInstance();
        
        void enter(U4DTouches *uTouches);
        
        void execute(U4DTouches *uTouches, double dt);
        
        void exit(U4DTouches *uTouches);
        
    };
    
}
#endif /* U4DTouchesReleasedState_hpp */
