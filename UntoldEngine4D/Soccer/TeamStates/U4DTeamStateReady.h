//
//  U4DTeamStateReady.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateReady_hpp
#define U4DTeamStateReady_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"

namespace U4DEngine {

class U4DTeamStateReady:public U4DTeamStateInterface {

private:

    U4DTeamStateReady();
    
    ~U4DTeamStateReady();
    
public:
    
    static U4DTeamStateReady* instance;
    
    static U4DTeamStateReady* sharedInstance();
    
    void enter(U4DTeam *uTeam);
    
    void execute(U4DTeam *uTeam, double dt);
    
    void exit(U4DTeam *uTeam);
    
    bool isSafeToChangeState(U4DTeam *uTeam);
    
    bool handleMessage(U4DTeam *uTeam, Message &uMsg);
    
};

}
#endif /* U4DTeamStateReady_hpp */
