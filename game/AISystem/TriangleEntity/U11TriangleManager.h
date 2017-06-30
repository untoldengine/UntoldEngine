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
    
    U11TriangleEntity* triangleEntityRoot;
    
    std::vector<VertexNode> vertexNodeContainer;
    
    std::queue<SegmentNode> segmentQueue;
    
    int triangleEntityIndex;
    
public:
    
    U11TriangleManager();
    
    ~U11TriangleManager();
    
    void initTriangleEntitiesComputation(U11Team *uTeam);
    
    void buildInitialTriangleEntity(U11Team *uTeam);
    
    void buildTriangleEntities(U11Team *uTeam);
    
    std::vector<VertexNode> getVertexNodeContainer();
    
    std::vector<U11Player*> getPlayersInsidePlane(U11Team *uTeam, U4DEngine::U4DVector3n &uNormal, U4DEngine::U4DPoint3n &uPlanePoint);
    
    void removeAllTriangleNodes();
    
    void clearContainers();
    
    U11TriangleEntity *getTriangleEntityRoot();
    
};

#endif /* U11TriangleManager_hpp */
