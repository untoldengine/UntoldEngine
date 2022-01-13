//
//  U4DTeamStateIdle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateIdle_hpp
#define U4DTeamStateIdle_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"

namespace U4DEngine {

class U4DTeamStateIdle:public U4DTeamStateInterface {

private:

    U4DTeamStateIdle();
    
    ~U4DTeamStateIdle();
    
public:
    
    static U4DTeamStateIdle* instance;
    
    static U4DTeamStateIdle* sharedInstance();
    
    void enter(U4DTeam *uTeam);
    
    void execute(U4DTeam *uTeam, double dt);
    
    void exit(U4DTeam *uTeam);
    
    bool isSafeToChangeState(U4DTeam *uTeam);
    
    bool handleMessage(U4DTeam *uTeam, Message &uMsg);
    
};

}


#endif /* U4DTeamStateIdle_hpp */
