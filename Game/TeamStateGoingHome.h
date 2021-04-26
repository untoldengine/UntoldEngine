//
//  TeamStateGoingHome.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateGoingHome_hpp
#define TeamStateGoingHome_hpp

#include <stdio.h>
#include "TeamStateInterface.h"

class TeamStateGoingHome:public TeamStateInterface {

private:

    TeamStateGoingHome();
    
    ~TeamStateGoingHome();
    
public:
    
    static TeamStateGoingHome* instance;
    
    static TeamStateGoingHome* sharedInstance();
    
    void enter(Team *uTeam);
    
    void execute(Team *uTeam, double dt);
    
    void exit(Team *uTeam);
    
    bool isSafeToChangeState(Team *uTeam);
    
    bool handleMessage(Team *uTeam, Message &uMsg);
    
};
#endif /* TeamStateGoingHome_hpp */
