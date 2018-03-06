//
//  U4DKeys.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DKeys_hpp
#define U4DKeys_hpp

#include <stdio.h>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DMacKeyStateManager;
    class U4DMacKeyStateInterface;
}

namespace U4DEngine {
    
    class U4DMacKey:public U4DEntity{
        
    private:
        
        U4DMacKeyStateManager *stateManager;
        
        KEYBOARDELEMENT keyboardElementType;
        
    public:
        
        U4DMacKey(KEYBOARDELEMENT &uKeyboardElementType);
        
        ~U4DMacKey();
        
        U4DCallbackInterface *pCallback;
        
        U4DControllerInterface *controllerInterface;
        
        void update(double dt);
        
        void action();
        
        bool getIsPressed();
        
        bool getIsReleased();
        
        void changeState(KEYBOARDACTION &uKeyboardAction, const U4DVector2n &uPadAxis);
        
        KEYBOARDELEMENT getKeyboardElementType();
        
        void setCallbackAction(U4DCallbackInterface *uAction);
        
        void setControllerInterface(U4DControllerInterface* uControllerInterface);
    };
    
}
#endif /* U4DKeys_hpp */
