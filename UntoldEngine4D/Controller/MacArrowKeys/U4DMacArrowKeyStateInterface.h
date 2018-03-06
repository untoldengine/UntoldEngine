//
//  U4DMacArrowKeyStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DMacArrowKeyStateInterface_hpp
#define U4DMacArrowKeyStateInterface_hpp

#include <stdio.h>
#include "U4DMacArrowKey.h"

namespace U4DEngine {
    
    class U4DMacArrowKeyStateInterface {
        
        
    public:
        
        virtual ~U4DMacArrowKeyStateInterface(){};
        
        virtual void enter(U4DMacArrowKey *uMacArrowKey)=0;
        
        virtual void execute(U4DMacArrowKey *uMacArrowKey, double dt)=0;
        
        virtual void exit(U4DMacArrowKey *uMacArrowKey)=0;
        
    };
    
}
#endif /* U4DMacArrowKeyStateInterface_hpp */
