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

class TeamStateInterface;
class TeamStateManager;

class Team {
    
    private:
    
        //state manager
        TeamStateManager *stateManager;
    
        //declare the callback with the class name
        U4DEngine::U4DCallback<Team> *defenseScheduler;
        U4DEngine::U4DCallback<Team> *formationScheduler;
    
        //declare the timer
        std::vector<Player *> players;
        
        Team* oppositeTeam;
        
        Player* controllingPlayer;
        
        Player* markingPlayer;
        
        U4DEngine::U4DVector3n startingPosition;
        
        int playerIndex;
        
        
    public:
    
        Team();
        
        ~Team();
    
        void update(double dt);
    
        TeamStateInterface *getCurrentState();
        
        TeamStateInterface *getPreviousState();
    
        void changeState(TeamStateInterface *uState);
    
        void handleMessage(Message &uMsg);
    
        bool enableDefenseAnalyzer;
    
        U4DEngine::U4DTimer *defenseTimer;
    
        U4DEngine::U4DTimer *formationTimer;
    
        bool aiTeam;
    
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
    
        void sendTeamHome();
    
        void startAnalyzingDefense();
        
};
#endif /* Teams_hpp */
