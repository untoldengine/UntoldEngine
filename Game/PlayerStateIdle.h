//
//  PlayerStateIdle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateIdle_hpp
#define PlayerStateIdle_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateIdle:public PlayerStateInterface {

private:

    PlayerStateIdle();
    
    ~PlayerStateIdle();
    
public:
    
    static PlayerStateIdle* instance;
    
    static PlayerStateIdle* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    //bool handleMessage(Player *uPlayer, Message &uMsg);
    
};

#endif /* PlayerStateIdle_hpp */
