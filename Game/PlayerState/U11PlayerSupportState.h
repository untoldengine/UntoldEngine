//
//  U11PlayerSupportState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerOpenUpState_hpp
#define U11PlayerOpenUpState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerSupportState:public U11PlayerStateInterface {
    
private:
    
protected:
    
    U11PlayerSupportState();
    
    ~U11PlayerSupportState();
    
public:
    
    static U11PlayerSupportState* instance;
    
    static U11PlayerSupportState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerOpenUpState_hpp */
