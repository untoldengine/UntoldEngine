//
//  PlayerStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateInterface_hpp
#define PlayerStateInterface_hpp

#include <stdio.h>
#include "Player.h"
#include "UserCommonProtocols.h"

class PlayerStateInterface {
        
private:
    
    
    
public:
    
    std::string name;
    
    virtual ~PlayerStateInterface(){};
    
    virtual void enter(Player *uPlayer)=0;
    
    virtual void execute(Player *uPlayer, double dt)=0;
    
    virtual void exit(Player *uPlayer)=0;
    
    //virtual bool handleMessage(Player *uPlayer, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(Player *uPlayer)=0;
    
};
#endif /* PlayerStateInterface_hpp */
