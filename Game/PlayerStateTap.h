//
//  PlayerStateTap.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateTap_hpp
#define PlayerStateTap_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateTap:public PlayerStateInterface {

private:

    PlayerStateTap();
    
    ~PlayerStateTap();
    
public:
    
    static PlayerStateTap* instance;
    
    static PlayerStateTap* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateTap_hpp */
