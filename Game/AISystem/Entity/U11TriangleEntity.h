//
//  U11TriangleEntity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/9/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TriangleEntity_hpp
#define U11TriangleEntity_hpp

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"
#include "U4DTriangle.h"
#include "U11TriangleNode.h"

class U11Team;

class U11TriangleEntity {
    
private:
    
    TriangleNode triangleNode;
    
    int index;
    
    bool isTriangleEntitySafe;
    
public:
    
    U11TriangleEntity();
    
    ~U11TriangleEntity();
    
    void buildTriangleEntity(U11Team *uTeam);
    
    TriangleNode &getTriangleNode();
    
    U4DEngine::U4DTriangle getTriangleGeometry();
    
    U4DEngine::U4DPoint3n getTriangleCentroid();
    
    std::vector<U11Player*> getThreatPlayersInsideTriangle();
    
    bool getIsTriangleEntitySafe();
    
};

#endif /* U11TriangleEntity_hpp */
