//
//  U4DMatchManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMatchManager_hpp
#define U4DMatchManager_hpp

#include <stdio.h>
#include "U4DTeam.h"
#include "U4DAABB.h"
#include "U4DField.h"
#include "U4DGoalPost.h"

namespace U4DEngine {

class U4DMatchManager {

private:
    
    static U4DMatchManager *instance;
    
    float fieldHalfWidth;
    float fieldHalfLength;
    U4DField *field;
    U4DAABB fieldAABB;
    
    U4DGoalPost *goalPost0;
    U4DGoalPost *goalPost1;
    
    int state;
    
protected:
    
    U4DMatchManager();
    
    ~U4DMatchManager();
    
public:
    
    U4DTeam *teamA;
    U4DTeam *teamB;
    
    //bool goalScored;
    bool ballOutOfBound;
    
    static U4DMatchManager *sharedInstance();
    
    void update(double dt);
    
    void initMatch(U4DGoalPost *uGoalPost0, U4DGoalPost *uGoalPost1, U4DField *uField);
    
    bool checkIfBallOutOfBounds();
    
    void computeReflectedVelocityForBall(double dt);
    
    void setState(int uState);
    
    int getState();
    
    void changeState(int uState);
    
    U4DGoalPost *getTeamAGoalPost();
    
    U4DGoalPost *getTeamBGoalPost();
    
};

}


#endif /* U4DMatchManager_hpp */
