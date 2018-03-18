//
//  U4DPadButtonStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadButtonStateInterface_hpp
#define U4DPadButtonStateInterface_hpp

#include <stdio.h>
#include "U4DPadButton.h"

namespace U4DEngine {
    
    class U4DPadButtonStateInterface {
        
        
    public:
        
        virtual ~U4DPadButtonStateInterface(){};
        
        virtual void enter(U4DPadButton *uPadButton)=0;
        
        virtual void execute(U4DPadButton *uPadButton, double dt)=0;
        
        virtual void exit(U4DPadButton *uPadButton)=0;
        
    };
    
}
#endif /* U4DPadButtonStateInterface_hpp */
