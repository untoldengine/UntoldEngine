//
//  U4DTeamStateAttacking.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateAttacking_hpp
#define U4DTeamStateAttacking_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"

namespace U4DEngine{

class U4DTeamStateAttacking:public U4DTeamStateInterface {

private:

    U4DTeamStateAttacking();
    
    ~U4DTeamStateAttacking();
    
public:
    
    static U4DTeamStateAttacking* instance;
    
    static U4DTeamStateAttacking* sharedInstance();
    
    void enter(U4DTeam *uTeam);
    
    void execute(U4DTeam *uTeam, double dt);
    
    void exit(U4DTeam *uTeam);
    
    bool isSafeToChangeState(U4DTeam *uTeam);
    
    bool handleMessage(U4DTeam *uTeam, Message &uMsg);
    
};

}

#endif /* U4DTeamStateAttacking_hpp */
