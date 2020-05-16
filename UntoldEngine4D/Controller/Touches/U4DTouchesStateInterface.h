//
//  U4DTouchesStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTouchesStateInterface_hpp
#define U4DTouchesStateInterface_hpp

#include <stdio.h>
#include "U4DTouches.h"

namespace U4DEngine {
    
    class U4DTouchesStateInterface {
        
        
    public:
        
        virtual ~U4DTouchesStateInterface(){};
        
        virtual void enter(U4DTouches *uTouches)=0;
        
        virtual void execute(U4DTouches *uTouches, double dt)=0;
        
        virtual void exit(U4DTouches *uTouches)=0;
        
    };
    
}

#endif /* U4DTouchesStateInterface_hpp */
