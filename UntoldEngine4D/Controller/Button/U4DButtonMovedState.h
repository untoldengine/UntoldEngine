//
//  U4DButtonMovedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DButtonMovedState_hpp
#define U4DButtonMovedState_hpp

#include <stdio.h>
#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DButtonMovedState:public U4DButtonStateInterface {
        
    private:
        
        U4DButtonMovedState();
        
        ~U4DButtonMovedState();
        
    public:
        
        static U4DButtonMovedState* instance;
        
        static U4DButtonMovedState* sharedInstance();
        
        void enter(U4DButton *uButton);
        
        void execute(U4DButton *uButton, double dt);
        
        void exit(U4DButton *uButton);
        
    };
    
}
#endif /* U4DButtonMovedState_hpp */
