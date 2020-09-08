//
//  PlayerStateIntercept.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateIntercept_hpp
#define PlayerStateIntercept_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateIntercept:public PlayerStateInterface {

private:

    PlayerStateIntercept();
    
    ~PlayerStateIntercept();
    
public:
    
    static PlayerStateIntercept* instance;
    
    static PlayerStateIntercept* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateIntercept_hpp */
