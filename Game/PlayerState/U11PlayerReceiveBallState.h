//
//  U11PlayerReceiveBallState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerReceiveBallState_hpp
#define U11PlayerReceiveBallState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerReceiveBallState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerReceiveBallState();
    
    ~U11PlayerReceiveBallState();
    
public:
    
    static U11PlayerReceiveBallState* instance;
    
    static U11PlayerReceiveBallState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerReceiveBallState_hpp */
