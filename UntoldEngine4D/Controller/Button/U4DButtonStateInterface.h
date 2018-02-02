//
//  U4DButtonStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DButtonStateInterface_hpp
#define U4DButtonStateInterface_hpp

#include <stdio.h>
#include "U4DButton.h"

namespace U4DEngine {
    
    class U4DButtonStateInterface {
        
        
    public:
        
        virtual ~U4DButtonStateInterface(){};
        
        virtual void enter(U4DButton *uButton)=0;
        
        virtual void execute(U4DButton *uButton, double dt)=0;
        
        virtual void exit(U4DButton *uButton)=0;
        
    };
    
}

#endif /* U4DButtonStateInterface_hpp */
