//
//  U4DMatchRef.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMatchRef_hpp
#define U4DMatchRef_hpp

#include <stdio.h>
#include "U4DTeam.h"
#include "U4DAABB.h"
#include "U4DField.h"
#include "U4DGoalPost.h"

namespace U4DEngine {

class U4DMatchRef {

private:
    
    static U4DMatchRef *instance;
    
    float fieldHalfWidth;
    float fieldHalfLength;
    U4DField *field;
    U4DAABB fieldAABB;
    
    U4DGoalPost *goalPost0;
    U4DGoalPost *goalPost1;
    
    bool goalScored;
    bool ballOutOfBound;
    
protected:
    
    U4DMatchRef();
    
    ~U4DMatchRef();
    
public:
    
    static U4DMatchRef *sharedInstance();
    
    void update(double dt);
    
    void initMatch(U4DTeam *uTeamA, U4DTeam *uTeamB, U4DGoalPost *uGoalPost0, U4DGoalPost *uGoalPost1, U4DField *uField);
    
    bool checkIfBallOutOfBounds();
    
    void computeReflectedVelocityForBall(double dt);
};

}


#endif /* U4DMatchRef_hpp */
