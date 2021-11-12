//
//  PlayerStateDribbling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateDribbling_hpp
#define PlayerStateDribbling_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"

class PlayerStateDribbling:public PlayerStateInterface {

private:

    PlayerStateDribbling();
    
    ~PlayerStateDribbling();
    
public:
    
    static PlayerStateDribbling* instance;
    
    static PlayerStateDribbling* sharedInstance();
    
    void enter(Player *uPlayer);
    
    void execute(Player *uPlayer, double dt);
    
    void exit(Player *uPlayer);
    
    bool isSafeToChangeState(Player *uPlayer);
    
    //bool handleMessage(Player *uPlayer, Message &uMsg);
    
};
#endif /* PlayerStateDribbling_hpp */
