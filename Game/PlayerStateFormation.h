//
//  PlayerStateFormation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateFormation_hpp
#define PlayerStateFormation_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateFormation:public PlayerStateInterface {

private:

    PlayerStateFormation();
    
    ~PlayerStateFormation();
    
public:
    
    static PlayerStateFormation* instance;
    
    static PlayerStateFormation* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateFormation_hpp */
