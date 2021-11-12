//
//  PlayerStateShooting.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateShooting_hpp
#define PlayerStateShooting_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateShooting:public PlayerStateInterface {

private:

    PlayerStateShooting();
    
    ~PlayerStateShooting();
    
public:
    
    static PlayerStateShooting* instance;
    
    static PlayerStateShooting* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    //bool handleMessage(Player *uPlayer, Message &uMsg);
    
};

#endif /* PlayerStateShooting_hpp */
