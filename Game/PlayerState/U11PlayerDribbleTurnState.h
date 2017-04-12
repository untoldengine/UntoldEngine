//
//  U11PlayerDribbleTurn.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerDribbleTurn_hpp
#define U11PlayerDribbleTurn_hpp

#include <stdio.h>
#include "U11PlayerStateInterface.h"

class U11PlayerDribbleTurnState:public U11PlayerStateInterface {
    
private:
    
    U11PlayerDribbleTurnState();
    
    ~U11PlayerDribbleTurnState();
    
public:
    
    static U11PlayerDribbleTurnState* instance;
    
    static U11PlayerDribbleTurnState* sharedInstance();
    
    void enter(U11Player *uPlayer);
    
    void execute(U11Player *uPlayer, double dt);
    
    void exit(U11Player *uPlayer);
    
    bool isSafeToChangeState(U11Player *uPlayer);
    
    bool handleMessage(U11Player *uPlayer, Message &uMsg);
    
};
#endif /* U11PlayerDribbleTurn_hpp */
