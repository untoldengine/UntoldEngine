//
//  U11PlayerTurnPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerTurnPassState_hpp
#define U11PlayerTurnPassState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerTurnPassState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerTurnPassState();
    
    ~U11PlayerTurnPassState();
    
public:
    
    static U11PlayerTurnPassState* instance;
    
    static U11PlayerTurnPassState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerTurnPassState_hpp */
