//
//  U11PlayerTapToStealState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerTapToStealState_hpp
#define U11PlayerTapToStealState_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerTapToStealState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerTapToStealState();
    
    ~U11PlayerTapToStealState();
    
public:
    
    static U11PlayerTapToStealState* instance;
    
    static U11PlayerTapToStealState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerTapToStealState_hpp */
