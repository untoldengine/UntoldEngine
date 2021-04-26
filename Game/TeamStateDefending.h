//
//  TeamStateDefending.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateDefending_hpp
#define TeamStateDefending_hpp

#include <stdio.h>
#include "TeamStateInterface.h"

class TeamStateDefending:public TeamStateInterface {

private:

    TeamStateDefending();
    
    ~TeamStateDefending();
    
public:
    
    static TeamStateDefending* instance;
    
    static TeamStateDefending* sharedInstance();
    
    void enter(Team *uTeam);
    
    void execute(Team *uTeam, double dt);
    
    void exit(Team *uTeam);
    
    bool isSafeToChangeState(Team *uTeam);
    
    bool handleMessage(Team *uTeam, Message &uMsg);
    
};
#endif /* TeamStateDefending_hpp */
