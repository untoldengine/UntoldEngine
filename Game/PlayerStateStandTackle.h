//
//  PlayerStateStandTackle.hpp
//  Footballer
//
//  Created by Harold Serrano on 11/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateStandTackle_hpp
#define PlayerStateStandTackle_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateStandTackle:public PlayerStateInterface {

private:

    PlayerStateStandTackle();
    
    ~PlayerStateStandTackle();
    
public:
    
    static PlayerStateStandTackle* instance;
    
    static PlayerStateStandTackle* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateStandTackle_hpp */
