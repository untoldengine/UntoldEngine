//
//  U4DPadButtonReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadButtonReleasedState_hpp
#define U4DPadButtonReleasedState_hpp

#include <stdio.h>
#include "U4DPadButton.h"
#include "U4DPadButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DPadButtonReleasedState:public U4DPadButtonStateInterface {
        
    private:
        
        U4DPadButtonReleasedState();
        
        ~U4DPadButtonReleasedState();
        
    public:
        
        static U4DPadButtonReleasedState* instance;
        
        static U4DPadButtonReleasedState* sharedInstance();
        
        void enter(U4DPadButton *uPadButton);
        
        void execute(U4DPadButton *uPadButton, double dt);
        
        void exit(U4DPadButton *uPadButton);
        
    };
    
}
#endif /* U4DPadButtonReleasedState_hpp */
