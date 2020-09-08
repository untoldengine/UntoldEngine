//
//  PlayerStateGroupNav.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateGroupNav_hpp
#define PlayerStateGroupNav_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateGroupNav:public PlayerStateInterface {

private:

    PlayerStateGroupNav();
    
    ~PlayerStateGroupNav();
    
public:
    
    static PlayerStateGroupNav* instance;
    
    static PlayerStateGroupNav* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};

#endif /* PlayerStateGroupNav_hpp */
