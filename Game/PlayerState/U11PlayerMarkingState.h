//
//  U11PlayerMarkingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerMarkingState_hpp
#define U11PlayerMarkingState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerMarkingState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerMarkingState();
    
    ~U11PlayerMarkingState();
    
public:
    
    static U11PlayerMarkingState* instance;
    
    static U11PlayerMarkingState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerMarkingState_hpp */
