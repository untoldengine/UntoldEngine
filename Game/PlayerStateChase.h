//
//  PlayerStateChase.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateChase_hpp
#define PlayerStateChase_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateChase:public PlayerStateInterface {

private:

    PlayerStateChase();
    
    ~PlayerStateChase();
    
public:
    
    static PlayerStateChase* instance;
    
    static PlayerStateChase* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateChase_hpp */
