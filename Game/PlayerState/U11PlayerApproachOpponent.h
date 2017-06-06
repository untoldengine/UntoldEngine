//
//  U11PlayerApproachOpponent.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerApproachOpponent_hpp
#define U11PlayerApproachOpponent_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerApproachOpponent:public U11PlayerStateInterface {
    
private:
    
    U11PlayerApproachOpponent();
    
    ~U11PlayerApproachOpponent();
    
public:
    
    static U11PlayerApproachOpponent* instance;
    
    static U11PlayerApproachOpponent* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};

#endif /* U11PlayerApproachOpponent_hpp */
