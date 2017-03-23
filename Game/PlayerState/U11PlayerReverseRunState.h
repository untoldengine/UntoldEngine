//
//  U11PlayerReverseRunState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerReverseRunState_hpp
#define U11PlayerReverseRunState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerReverseRunState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerReverseRunState();
    
    ~U11PlayerReverseRunState();
    
public:
    
    static U11PlayerReverseRunState* instance;
    
    static U11PlayerReverseRunState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerReverseRunState_hpp */
