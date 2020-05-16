//
//  U4DTouchesPressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesPressedState_hpp
#define U4DTouchesPressedState_hpp

#include <stdio.h>
#include "U4DTouches.h"
#include "U4DTouchesStateInterface.h"

namespace U4DEngine {
    
    class U4DTouchesPressedState:public U4DTouchesStateInterface {
        
    private:
        
        U4DTouchesPressedState();
        
        ~U4DTouchesPressedState();
        
    public:
        
        static U4DTouchesPressedState* instance;
        
        static U4DTouchesPressedState* sharedInstance();
        
        void enter(U4DTouches *uTouches);
        
        void execute(U4DTouches *uTouches, double dt);
        
        void exit(U4DTouches *uTouches);
        
    };
    
}
#endif /* U4DTouchesPressedState_hpp */
