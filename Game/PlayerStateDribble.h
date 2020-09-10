//
//  PlayerStateDribble.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateDribble_hpp
#define PlayerStateDribble_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateDribble:public PlayerStateInterface {

private:

    PlayerStateDribble();
    
    ~PlayerStateDribble();
    
public:
    
    static PlayerStateDribble* instance;
    
    static PlayerStateDribble* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateDribble_hpp */
