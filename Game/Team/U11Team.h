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
#include "U11AIAnalyzer.h"

class U11Ball;

class U11Team {
    
private:

    std::vector<U11Player*> teammates;
    
    //pointers to key players
    U11Player *controllingPlayer;
    
    U11Player *supportPlayer1;
    
    U11Player *supportPlayer2;
    
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
    
    void setSupportPlayer1(U11Player *uPlayer);
    
    U11Player* getSupportPlayer1();
    
    void setSupportPlayer2(U11Player *uPlayer);
    
    U11Player* getSupportPlayer2();
    
    void assignSupportPlayer();
    
    std::vector<U11Player*> analyzeSupportPlayers();
    
    std::vector<U11Player*> analyzeClosestPlayersToBall();
    
    std::vector<U11Player*> analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition);
    
    std::vector<U11Player*> analyzeClosestPlayersAlongPassLine();
    
    void computeSupportSpace();
    
};

#endif /* U11Team_hpp */
