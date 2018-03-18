//
//  U4DMacArrowKeyActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacArrowKeyPressedState_hpp
#define U4DMacArrowKeyPressedState_hpp

#include <stdio.h>
#include "U4DMacArrowKey.h"
#include "U4DMacArrowKeyStateInterface.h"

namespace U4DEngine {
    
    class U4DMacArrowKeyActiveState:public U4DMacArrowKeyStateInterface {
        
    private:
        
        U4DMacArrowKeyActiveState();
        
        ~U4DMacArrowKeyActiveState();
        
    public:
        
        static U4DMacArrowKeyActiveState* instance;
        
        static U4DMacArrowKeyActiveState* sharedInstance();
        
        void enter(U4DMacArrowKey *uMacArrowKey);
        
        void execute(U4DMacArrowKey *uMacArrowKey, double dt);
        
        void exit(U4DMacArrowKey *uMacArrowKey);
        
    };
    
}
#endif /* U4DMacArrowKeyPressedState_hpp */
