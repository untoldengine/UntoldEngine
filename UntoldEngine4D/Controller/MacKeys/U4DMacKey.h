//
//  U4DKeys.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DKeys_hpp
#define U4DKeys_hpp

#include <stdio.h>
#include <vector>
#include "U4DCallbackInterface.h"
#include "U4DInputElement.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacKeyStateManager;
    class U4DMacKeyStateInterface;
}

namespace U4DEngine {
    
    class U4DMacKey:public U4DInputElement{
        
    private:
        
        U4DMacKeyStateManager *stateManager;
        
    public:
        
        U4DMacKey(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface);
        
        ~U4DMacKey();
        
        void update(double dt);
        
        void action();
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        void changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition);
        
        
        
    };
    
}
#endif /* U4DKeys_hpp */
