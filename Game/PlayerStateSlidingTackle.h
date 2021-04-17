//
//  PlayerStateSlidingTackle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateSlidingTackle_hpp
#define PlayerStateSlidingTackle_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateSlidingTackle:public PlayerStateInterface {

private:

    PlayerStateSlidingTackle();
    
    ~PlayerStateSlidingTackle();
    
public:
    
    static PlayerStateSlidingTackle* instance;
    
    static PlayerStateSlidingTackle* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateSlidingTackle_hpp */
