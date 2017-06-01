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
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DWorld.h"

class U11Ball;
class U11FieldGoal;
class U11FormationInterface;
class U11Field;
class U11AISystem;
class U11AIStateInterface;


class U11Team {
    
private:

    std::vector<U11Player*> teammates;
    
    //pointers to key players
    U11Player *controllingPlayer;
    
    U11Player *supportPlayer1;
    
    U11Player *supportPlayer2;
    
    U11Player *mainDefendingPlayer;
    
    U11Player *supportDefendingPlayer1;
    
    U11Player *supportDefendingPlayer2;
    
    U11Player *previousMainControllingPlayer;
    
    U11Player *previousMainDefendingPlayer;
    
    U11Player *playerWithIndicator;
    
    U11Team *oppositeTeam;
    
    U11Ball *soccerBall;
    
    U11FieldGoal *fieldGoal;
    
    U11FormationInterface *teamFormation;
    
    int fieldQuadrant;
    
    U11AISystem *aiSystem;
    
    
    
public:
    
    U11Team(U11FormationInterface *uTeamFormation, U4DEngine::U4DWorld *uWorld, int uFieldQuadrant);
    
    ~U11Team();
    
    void subscribe(U11Player* uPlayer);
    
    void remove(U11Player* uPlayer);
    
    void setSoccerBall(U11Ball *uSoccerBall);
    
    void setFieldGoal(U11FieldGoal *uFieldGoal);
    
    U11Ball *getSoccerBall();
    
    U11FieldGoal *getFieldGoal();
      
    std::vector<U11Player*> getTeammates();
    
    U11Team *getOppositeTeam();
    
    void setOppositeTeam(U11Team *uTeam);
    
    U11Player* getControllingPlayer();
    
    void setControllingPlayer(U11Player* uPlayer);
    
    U11Player* getActivePlayer();
    
    void setSupportPlayer1(U11Player *uPlayer);
    
    U11Player* getSupportPlayer1();
    
    void setSupportPlayer2(U11Player *uPlayer);
    
    U11Player* getSupportPlayer2();
    
    void setMainDefendingPlayer(U11Player *uPlayer);
    
    U11Player *getMainDefendingPlayer();
    
    void setSupportDefendingPlayer1(U11Player *uPlayer);
    
    U11Player *getSupportDefendingPlayer1();
    
    void setSupportDefendingPlayer2(U11Player *uPlayer);
    
    U11Player *getSupportDefendingPlayer2();
    
    void changeState(U11AIStateInterface* uState);

    void translateTeamToFormationPosition();
    
    void updateTeamFormationPosition();
    
    bool handleMessage(Message &uMsg);
    
    U11FormationInterface *getTeamFormation();
    
    U11AISystem *getAISystem();
    
    void resetAttackingPlayers();
    
    void resetDefendingPlayers();
    
    void setIndicatorForPlayer(U11Player *uPlayer);
    
    U11Player *getIndicatorForPlayer();
    
};

#endif /* U11Team_hpp */
