//
//  PlayerStateWander.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateWander_hpp
#define PlayerStateWander_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateWander:public PlayerStateInterface {

private:

    PlayerStateWander();
    
    ~PlayerStateWander();
    
public:
    
    static PlayerStateWander* instance;
    
    static PlayerStateWander* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateWander_hpp */
