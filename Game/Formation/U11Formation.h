//
//  U11Formation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Formation_hpp
#define U11Formation_hpp

#include <stdio.h>
#include <vector>
#include "U11FormationInterface.h"
#include "U4DWorld.h"

class U11FormationEntity;

class U11Formation:public U11FormationInterface {
    
private:
    
protected:
    
    U11FormationEntity *mainParent;
    
    int fieldQuadrant;
    
public:
    
    U11Formation();
    
    ~U11Formation();
    
    void init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant){};
    
    void translateAllEntitiesToOrigin();
    
    U11FormationEntity *assignFormationEntity();
    
    void translateFormation(U4DEngine::U4DVector3n &uPosition);
};

#endif /* U11Formation_hpp */
