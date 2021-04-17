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
#include "FormationManager.h"

class Team {
    
    private:
    
        U4DEngine::U4DGameObject *spotManager;
        
        //declare the callback with the class name
        U4DEngine::U4DCallback<Team> *analyzerScheduler;
        U4DEngine::U4DCallback<Team> *formationScheduler;
    
        //declare the timer
        U4DEngine::U4DTimer *analyzerTimer;
        U4DEngine::U4DTimer *formationTimer;
        
        std::vector<Player *> players;
        
        Team* oppositeTeam;
        
        Player* controllingPlayer;
        
        Player* markingPlayer;
        
        U4DEngine::U4DVector3n startingPosition;
        
        int playerIndex;
        
        
    
    public:
    
        Team();
        
        ~Team();
    
        FormationManager formationManager;
        
        void addPlayer(Player *uPlayer);
        
        std::vector<Player *> getPlayers();
        
        std::vector<Player *> getTeammatesForPlayer(Player *uPlayer);

        void startAnalyzing();

        void analyzeField();
    
        void updateFormation();
        
        void setOppositeTeam(Team *uTeam);
        
        void setControllingPlayer(Player *uPlayer);
        
        void setMarkingPlayer(Player *uPlayer);
        
        Player *getControllingPlayer();
        
        Player *getMarkingPlayer();
        
};
#endif /* Teams_hpp */
