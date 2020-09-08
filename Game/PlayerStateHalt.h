//
//  PlayerStateHalt.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateHalt_hpp
#define PlayerStateHalt_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateHalt:public PlayerStateInterface {

private:

    PlayerStateHalt();
    
    ~PlayerStateHalt();
    
public:
    
    static PlayerStateHalt* instance;
    
    static PlayerStateHalt* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateHalt_hpp */
