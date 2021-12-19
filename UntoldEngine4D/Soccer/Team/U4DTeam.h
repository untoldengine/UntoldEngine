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

namespace U4DEngine {

    class U4DTeam {

    private:
        
        //player containers
        std::vector<U4DPlayer *> players;
        
        U4DPlayer* controllingPlayer;
        
    public:
        
        U4DTeam();
        
        ~U4DTeam();
        
        void addPlayer(U4DPlayer *uPlayer);
        
        std::vector<U4DPlayer *> getPlayers();
        
        std::vector<U4DPlayer *>getTeammatesForPlayer(U4DPlayer *uPlayer);
        
        void setControllingPlayer(U4DPlayer *uPlayer);
        
        U4DPlayer *getControllingPlayer();
        
    };

}


#endif /* U4DTeam_hpp */
