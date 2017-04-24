//
//  U11Formation32.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Formation32_hpp
#define U11Formation32_hpp

#include <stdio.h>
#include "U11Formation.h"
#include "U4DWorld.h"

class U11FormationEntity;

class U11Formation32:public U11Formation {
    
private:
    
    U11FormationEntity *leftDefense;
    U11FormationEntity *rightDefense;
    U11FormationEntity *centerMid;
    U11FormationEntity *leftForward;
    U11FormationEntity *rightForward;
    
public:
    
    U11Formation32();
    
    ~U11Formation32();
    
    void init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant);
};

#endif /* U11Formation32_hpp */
