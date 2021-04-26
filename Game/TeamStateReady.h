//
//  TeamStateReady.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateReady_hpp
#define TeamStateReady_hpp

#include <stdio.h>
#include "TeamStateInterface.h"

class TeamStateReady:public TeamStateInterface {

private:

    TeamStateReady();
    
    ~TeamStateReady();
    
public:
    
    static TeamStateReady* instance;
    
    static TeamStateReady* sharedInstance();
    
    void enter(Team *uTeam);
    
    void execute(Team *uTeam, double dt);
    
    void exit(Team *uTeam);
    
    bool isSafeToChangeState(Team *uTeam);
    
    bool handleMessage(Team *uTeam, Message &uMsg);
    
};
#endif /* TeamStateReady_hpp */
