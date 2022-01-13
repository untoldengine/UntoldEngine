//
//  U4DTeam.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeam_hpp
#define U4DTeam_hpp

#include <stdio.h>
#include "U4DPlayer.h"
#include "U4DFormationManager.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DFieldAnalyzer.h"
#include "U4DPathAnalyzer.h"

namespace U4DEngine {

    class U4DTeamStateInterface;
    class U4DTeamStateManager;

    class U4DTeam {

    private:
        
        U4DTeamStateManager *stateManager;
        
        //player containers
        std::vector<U4DPlayer *> players;
        
        U4DPlayer* activePlayer;
        
        int playerIndex;
        
        U4DEngine::U4DCallback<U4DTeam> *defenseScheduler;
        U4DEngine::U4DCallback<U4DTeam> *formationScheduler;
        U4DEngine::U4DCallback<U4DTeam> *analyzerFieldScheduler;
        
        U4DTeam* oppositeTeam;
        
    public:
        
        U4DFormationManager formationManager;
        
        U4DTeam();
        
        ~U4DTeam();
        
        bool aiTeam;
        
        bool enableDefenseAnalyzer;
        
        U4DEngine::U4DTimer *defenseTimer;
        U4DEngine::U4DTimer *formationTimer;
        U4DEngine::U4DTimer *analyzerFieldTimer;
        
        void update(double dt);

        U4DTeamStateInterface *getCurrentState();

        U4DTeamStateInterface *getPreviousState();

        void changeState(U4DTeamStateInterface *uState);
        
        void addPlayer(U4DPlayer *uPlayer);
        
        std::vector<U4DPlayer *> getPlayers();
        
        std::vector<U4DPlayer *>getTeammatesForPlayer(U4DPlayer *uPlayer);
        
        void setActivePlayer(U4DPlayer *uPlayer);
        
        U4DPlayer *getActivePlayer();
        
        void updateFormation();
        
        void initAnalyzerSchedulers();
        
        void startAnalyzingDefense();
        
        void analyzeField();

        void setOppositeTeam(U4DTeam *uTeam);
    
        U4DTeam *getOppositeTeam();
        
    };

}


#endif /* U4DTeam_hpp */
