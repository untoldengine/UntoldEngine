//
//  TeamStateIdle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateIdle_hpp
#define TeamStateIdle_hpp

#include <stdio.h>
#include "TeamStateInterface.h"

class TeamStateIdle:public TeamStateInterface {

private:

    TeamStateIdle();
    
    ~TeamStateIdle();
    
public:
    
    static TeamStateIdle* instance;
    
    static TeamStateIdle* sharedInstance();
    
    void enter(Team *uTeam);
    
    void execute(Team *uTeam, double dt);
    
    void exit(Team *uTeam);
    
    bool isSafeToChangeState(Team *uTeam);
    
    bool handleMessage(Team *uTeam, Message &uMsg);
    
};
#endif /* TeamStateIdle_hpp */
