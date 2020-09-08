//
//  PlayerStatePass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStatePass_hpp
#define PlayerStatePass_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStatePass:public PlayerStateInterface {

private:

    PlayerStatePass();
    
    ~PlayerStatePass();
    
public:
    
    static PlayerStatePass* instance;
    
    static PlayerStatePass* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStatePass_hpp */
