//
//  U11PlayerLateralRunState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerLateralRunState_hpp
#define U11PlayerLateralRunState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerLateralRunState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerLateralRunState();
    
    ~U11PlayerLateralRunState();
    
public:
    
    static U11PlayerLateralRunState* instance;
    
    static U11PlayerLateralRunState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerLateralRunState_hpp */
