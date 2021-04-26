//
//  PlayerStateGoHome.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateGoHome_hpp
#define PlayerStateGoHome_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateGoHome:public PlayerStateInterface {

private:

    PlayerStateGoHome();
    
    ~PlayerStateGoHome();
    
public:
    
    static PlayerStateGoHome* instance;
    
    static PlayerStateGoHome* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};

#endif /* PlayerStateGoHome_hpp */
