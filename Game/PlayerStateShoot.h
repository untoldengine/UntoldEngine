//
//  PlayerStateShoot.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateShoot_hpp
#define PlayerStateShoot_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateShoot:public PlayerStateInterface {

private:

    PlayerStateShoot();
    
    ~PlayerStateShoot();
    
public:
    
    static PlayerStateShoot* instance;
    
    static PlayerStateShoot* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateShoot_hpp */
