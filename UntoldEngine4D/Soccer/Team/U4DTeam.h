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

namespace U4DEngine {

    class U4DTeam {

    private:
        
        //player containers
        std::vector<U4DPlayer *> players;
        
        U4DPlayer* controllingPlayer;
        
        int playerIndex;
        
        U4DEngine::U4DCallback<U4DTeam> *formationScheduler;
        U4DEngine::U4DTimer *formationTimer;
        
    public:
        
        U4DFormationManager formationManager;
        
        U4DTeam();
        
        ~U4DTeam();
        
        void addPlayer(U4DPlayer *uPlayer);
        
        std::vector<U4DPlayer *> getPlayers();
        
        std::vector<U4DPlayer *>getTeammatesForPlayer(U4DPlayer *uPlayer);
        
        void setControllingPlayer(U4DPlayer *uPlayer);
        
        U4DPlayer *getControllingPlayer();
        
        void updateFormation();
        
        void initAnalyzerSchedulers();
        
    };

}


#endif /* U4DTeam_hpp */
