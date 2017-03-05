//
//  U11Team.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Team_hpp
#define U11Team_hpp

#include <stdio.h>
#include <vector>
#include "U11Player.h"

class U11Team {
    
private:

    std::vector<U11Player*> teammates;
    
    //pointers to key players
    U11Player *controllingPlayer;
    
    U11Player *receivingPlayer;
    
    U11Player *playerClosestToBall;
    
    U11Player *supportingPlayer;
    
public:
    
    U11Team();
    
    ~U11Team();
    
    void subscribe(U11Player* uPlayer);
    
    void remove(U11Player* uPlayer);
    
    void setControllingPlayer(U11Player *uPlayer);
    
    void setReceivingPlayer(U11Player *uPlayer);
    
    void setSupportingPlayer(U11Player *uPlayer);
    
    void setPlayerClosestToBall(U11Player *uPlayer);
    
    U11Player *getControllingPlayer();
    
    U11Player *getReceivingPlayer();
    
    U11Player *getSupportingPlayer();
    
    U11Player *getPlayerClosestToBall();
    
};

#endif /* U11Team_hpp */
