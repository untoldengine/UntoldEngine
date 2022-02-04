//
//  U4DTeamStateGoHome.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateGoHome_hpp
#define U4DTeamStateGoHome_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"

namespace U4DEngine {

class U4DTeamStateGoHome:public U4DTeamStateInterface {

private:

    U4DTeamStateGoHome();
    
    ~U4DTeamStateGoHome();
    
public:
    
    static U4DTeamStateGoHome* instance;
    
    static U4DTeamStateGoHome* sharedInstance();
    
    void enter(U4DTeam *uTeam);
    
    void execute(U4DTeam *uTeam, double dt);
    
    void exit(U4DTeam *uTeam);
    
    bool isSafeToChangeState(U4DTeam *uTeam);
    
    bool handleMessage(U4DTeam *uTeam, Message &uMsg);
    
};

}

#endif /* U4DTeamStateGoHome_hpp */
