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

namespace U4DEngine {

class U4DMatchRef {

private:
    
    static U4DMatchRef *instance;
    
    float fieldHalfWidth;
    float fieldHalfLength;
    U4DField *field;
    U4DAABB fieldAABB;
    
protected:
    
    U4DMatchRef();
    
    ~U4DMatchRef();
    
public:
    
    static U4DMatchRef *sharedInstance();
    
    void update(double dt);
    
    void setField(U4DField *uField);
    
    void startMatch(U4DTeam *uTeamA, U4DTeam *uTeamB);
    
    bool checkIfBallOutOfBounds();
    
    void computeReflectedVelocityForBall(double dt);
};

}


#endif /* U4DMatchRef_hpp */
