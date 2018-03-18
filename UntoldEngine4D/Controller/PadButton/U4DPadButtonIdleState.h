//
//  U4DPadButtonIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadButtonIdleState_hpp
#define U4DPadButtonIdleState_hpp

#include <stdio.h>
#include "U4DPadButton.h"
#include "U4DPadButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DPadButtonIdleState:public U4DPadButtonStateInterface {
        
    private:
        
        U4DPadButtonIdleState();
        
        ~U4DPadButtonIdleState();
        
    public:
        
        static U4DPadButtonIdleState* instance;
        
        static U4DPadButtonIdleState* sharedInstance();
        
        void enter(U4DPadButton *uPadButton);
        
        void execute(U4DPadButton *uPadButton, double dt);
        
        void exit(U4DPadButton *uPadButton);
        
    };
    
}
#endif /* U4DPadButtonIdleState_hpp */
