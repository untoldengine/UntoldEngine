//
//  PlayerStateDefend.hpp
//  Footballer
//
//  Created by Harold Serrano on 11/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateDefend_hpp
#define PlayerStateDefend_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateDefend:public PlayerStateInterface {

private:

    PlayerStateDefend();
    
    ~PlayerStateDefend();
    
public:
    
    static PlayerStateDefend* instance;
    
    static PlayerStateDefend* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateDefend_hpp */
