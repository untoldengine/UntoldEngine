//
//  PlayerStateMark.hpp
//  Footballer
//
//  Created by Harold Serrano on 11/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateMark_hpp
#define PlayerStateMark_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateMark:public PlayerStateInterface {

private:

    PlayerStateMark();
    
    ~PlayerStateMark();
    
public:
    
    static PlayerStateMark* instance;
    
    static PlayerStateMark* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateMark_hpp */
