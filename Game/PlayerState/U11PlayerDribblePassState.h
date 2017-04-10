//
//  U11PlayerDribblePassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDribblePassState_hpp
#define U11PlayerDribblePassState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDribblePassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerDribblePassState();
    
    ~U11PlayerDribblePassState();
    
public:
    
    static U11PlayerDribblePassState* instance;
    
    static U11PlayerDribblePassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerDribblePassState_hpp */
