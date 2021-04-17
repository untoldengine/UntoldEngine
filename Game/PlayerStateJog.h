//
//  PlayerStateJog.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/10/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateJog_hpp
#define PlayerStateJog_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateJog:public PlayerStateInterface {

private:

    PlayerStateJog();
    
    ~PlayerStateJog();
    
public:
    
    static PlayerStateJog* instance;
    
    static PlayerStateJog* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateJog_hpp */
