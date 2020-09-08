//
//  Team.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/1/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Teams_hpp
#define Teams_hpp

#include <stdio.h>
#include "Player.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class Team {
    
    private:
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<Team> *scheduler;

    //declare the timer
    U4DEngine::U4DTimer *timer;
    
    std::vector<Player *> players;
    
    Team* oppositeTeam;
    
    Player* controllingPlayer;
    
    U4DEngine::U4DVector3n startingPosition;
    
    int playerIndex;
    
    std::vector<U4DEngine::U4DVector3n> formationPosition;
    
    public:
    
    Team();
    
    ~Team();
    
    void addPlayer(Player *uPlayer);
    
    std::vector<Player *> getPlayers();
    
    std::vector<Player *> getTeammatesForPlayer(Player *uPlayer);

    void startAnalyzing();

    void analyzeField();
    
    void setOppositeTeam(Team *uTeam);
    
    void setControllingPlayer(Player *uPlayer);
    
    Player *getControllingPlayer();
    
    void computeFormationPosition();
    
    std::vector<U4DEngine::U4DVector3n> getFormationPosition();
    
    U4DEngine::U4DVector3n getFormationPositionAtIndex(int uIndex);
    
};
#endif /* Teams_hpp */
