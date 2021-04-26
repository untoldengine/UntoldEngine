//
//  TeamStateAttacking.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateAttacking_hpp
#define TeamStateAttacking_hpp

#include <stdio.h>
#include "TeamStateInterface.h"

class TeamStateAttacking:public TeamStateInterface {

private:

    TeamStateAttacking();
    
    ~TeamStateAttacking();
    
public:
    
    static TeamStateAttacking* instance;
    
    static TeamStateAttacking* sharedInstance();
    
    void enter(Team *uTeam);
    
    void execute(Team *uTeam, double dt);
    
    void exit(Team *uTeam);
    
    bool isSafeToChangeState(Team *uTeam);
    
    bool handleMessage(Team *uTeam, Message &uMsg);
    
};
#endif /* TeamStateAttacking_hpp */
