//
//  U11PlayerAirShotState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerAirShotState_hpp
#define U11PlayerAirShotState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerAirShotState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerAirShotState();
    
    ~U11PlayerAirShotState();
    
public:
    
    static U11PlayerAirShotState* instance;
    
    static U11PlayerAirShotState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};

#endif /* U11PlayerAirShotState_hpp */
