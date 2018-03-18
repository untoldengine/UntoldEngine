//
//  U4DMacMouseStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMacMouseStateInterface_hpp
#define U4DMacMouseStateInterface_hpp

#include <stdio.h>
#include "U4DMacMouse.h"

namespace U4DEngine {
    
    class U4DMacMouseStateInterface {
        
        
    public:
        
        virtual ~U4DMacMouseStateInterface(){};
        
        virtual void enter(U4DMacMouse *uMacMouse)=0;
        
        virtual void execute(U4DMacMouse *uMacMouse, double dt)=0;
        
        virtual void exit(U4DMacMouse *uMacMouse)=0;
        
    };
    
}
#endif /* U4DMacMouseStateInterface_hpp */
