//
//  U4DButtonPressedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DButtonPressedState_hpp
#define U4DButtonPressedState_hpp

#include <stdio.h>
#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DButtonPressedState:public U4DButtonStateInterface {
        
    private:
        
        U4DButtonPressedState();
        
        ~U4DButtonPressedState();
        
    public:
        
        static U4DButtonPressedState* instance;
        
        static U4DButtonPressedState* sharedInstance();
        
        void enter(U4DButton *uButton);
        
        void execute(U4DButton *uButton, double dt);
        
        void exit(U4DButton *uButton);
        
    };
    
}
#endif /* U4DButtonPressedState_hpp */
