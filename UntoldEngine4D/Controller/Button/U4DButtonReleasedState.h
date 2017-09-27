//
//  U4DButtonReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DButtonReleasedState_hpp
#define U4DButtonReleasedState_hpp

#include <stdio.h>
#include "U4DButton.h"
#include "U4DButtonStateInterface.h"

namespace U4DEngine {
    
    class U4DButtonReleasedState:public U4DButtonStateInterface {
        
    private:
        
        U4DButtonReleasedState();
        
        ~U4DButtonReleasedState();
        
    public:
        
        static U4DButtonReleasedState* instance;
        
        static U4DButtonReleasedState* sharedInstance();
        
        void enter(U4DButton *uButton);
        
        void execute(U4DButton *uButton, double dt);
        
        void exit(U4DButton *uButton);
        
    };
    
}
#endif /* U4DButtonReleasedState_hpp */
