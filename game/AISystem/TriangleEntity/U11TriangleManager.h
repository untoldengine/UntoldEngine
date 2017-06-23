//
//  U11TriangleManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TriangleManager_hpp
#define U11TriangleManager_hpp

#include <stdio.h>
#include <queue>
#include "U11TriangleEntity.h"
#include "U4DSegment.h"

class U11Team;

class U11TriangleManager {
    
private:
    
    std::vector<U11TriangleEntity> triangleEntityContainer;
    
    std::vector<VertexNode> vertexNodeContainer;
    
    std::queue<SegmentNode> segmentQueue;
    
public:
    
    U11TriangleManager();
    
    ~U11TriangleManager();
    
    void initTriangleEntitiesComputation(U11Team *uTeam);
    
    void buildInitialTriangleEntity(U11Team *uTeam);
    
    void buildTriangleEntities(U11Team *uTeam);
    
    std::vector<VertexNode> getVertexNodeContainer();
    
    std::vector<U11TriangleEntity> getTriangleEntityContainer();
    
    std::vector<U11Player*> getPlayersInsidePlane(U11Team *uTeam, U4DEngine::U4DVector3n &uNormal, U4DEngine::U4DPoint3n &uPlanePoint);
    
};

#endif /* U11TriangleManager_hpp */
