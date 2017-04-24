//
//  U11FormationInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11FormationInterface_hpp
#define U11FormationInterface_hpp

#include <stdio.h>
#include "U4DWorld.h"


class U11FormationEntity;

class U11FormationInterface {
    
  
public:
    
    virtual ~U11FormationInterface(){};
    
    virtual void init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant)=0;
    
    virtual U11FormationEntity *assignFormationEntity()=0;
    
    virtual void translateFormation(U4DEngine::U4DVector3n &uPosition)=0;
};

#endif /* U11FormationInterface_hpp */
