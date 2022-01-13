//
//  U4DTeamStateDefending.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateDefending_hpp
#define U4DTeamStateDefending_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"

namespace U4DEngine{

class U4DTeamStateDefending:public U4DTeamStateInterface {

private:

    U4DTeamStateDefending();
    
    ~U4DTeamStateDefending();
    
public:
    
    static U4DTeamStateDefending* instance;
    
    static U4DTeamStateDefending* sharedInstance();
    
    void enter(U4DTeam *uTeam);
    
    void execute(U4DTeam *uTeam, double dt);
    
    void exit(U4DTeam *uTeam);
    
    bool isSafeToChangeState(U4DTeam *uTeam);
    
    bool handleMessage(U4DTeam *uTeam, Message &uMsg);
    
};

}

#endif /* U4DTeamStateDefending_hpp */
