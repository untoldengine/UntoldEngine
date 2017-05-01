//
//  U11Formation424.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/1/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Formation424_hpp
#define U11Formation424_hpp

#include <stdio.h>
#include "U11Formation.h"
#include "U4DWorld.h"

class U11FormationEntity;

class U11Formation442:public U11Formation {
    
private:
    
    U11FormationEntity *leftBackDefense;
    U11FormationEntity *centerLeftBackDefense;
    U11FormationEntity *centerRightBackDefense;
    U11FormationEntity *rightBackDefense;
    
    U11FormationEntity *leftWing;
    U11FormationEntity *leftMidfielder;
    U11FormationEntity *rightMidfielder;
    U11FormationEntity *rightWing;
    
    U11FormationEntity *leftCenterForward;
    U11FormationEntity *rightCenterForward;
    
public:
    
    U11Formation442();
    
    ~U11Formation442();
    
    void init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant);
};
#endif /* U11Formation424_hpp */
