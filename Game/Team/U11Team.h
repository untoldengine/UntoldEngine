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

class U11Ball;

class U11Team {
    
private:

    std::vector<U11Player*> teammates;
    
    //pointers to key players
    U11Player *controllingPlayer;
    
    U11Team *oppositeTeam;
    
    U11Ball *soccerBall;
    
public:
    
    U11Team();
    
    ~U11Team();
    
    void subscribe(U11Player* uPlayer);
    
    void remove(U11Player* uPlayer);
    
    void setSoccerBall(U11Ball *uSoccerBall);
    
    U11Ball *getSoccerBall();
      
    std::vector<U11Player*> getTeammates();
    
    U11Team *getOppositeTeam();
    
    U11Player* getControllingPlayer();
    
    void setControllingPlayer(U11Player* uPlayer);
    
    std::vector<U11Player*> getSupportPlayers();
    
    std::vector<U11Player*> getClosestPlayersToBall();
    
    std::vector<U11Player*> sortPlayersDistanceToPosition(U4DEngine::U4DVector3n &uPosition);
    
};

#endif /* U11Team_hpp */
