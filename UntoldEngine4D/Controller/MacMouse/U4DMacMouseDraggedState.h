//
//  U4DMacMouseDraggedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseDraggedState_hpp
#define U4DMacMouseDraggedState_hpp

#include <stdio.h>
#include "U4DMacMouse.h"
#include "U4DMacMouseStateInterface.h"

namespace U4DEngine {
    
    class U4DMacMouseDraggedState:public U4DMacMouseStateInterface {
        
    private:
        
        U4DMacMouseDraggedState();
        
        ~U4DMacMouseDraggedState();
        
        
        
    public:
        
        static U4DMacMouseDraggedState* instance;
        
        static U4DMacMouseDraggedState* sharedInstance();
        
        void enter(U4DMacMouse *uMacMouse);
        
        void execute(U4DMacMouse *uMacMouse, double dt);
        
        void exit(U4DMacMouse *uMacMouse);
        
    };
    
}
#endif /* U4DMacMouseDraggedState_hpp */
