//
//  U4DKeyStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DKeyStateInterface_hpp
#define U4DKeyStateInterface_hpp

#include <stdio.h>
#include "U4DMacKey.h"

namespace U4DEngine {
    
    class U4DMacKeyStateInterface {
        
        
    public:
        
        virtual ~U4DMacKeyStateInterface(){};
        
        virtual void enter(U4DMacKey *uMacKey)=0;
        
        virtual void execute(U4DMacKey *uMacKey, double dt)=0;
        
        virtual void exit(U4DMacKey *uMacKey)=0;
        
    };
    
}
#endif /* U4DKeyStateInterface_hpp */
