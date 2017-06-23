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
#include "U4DSegment.h"

class U11Player;

typedef struct{
    
    U11Player* player;
    U4DEngine::U4DPoint3n optimalPosition;
    
}VertexNode;


typedef struct{
    
    VertexNode nodeA;
    VertexNode nodeB;
    U4DEngine::U4DSegment segment;
    U4DEngine::U4DPoint3n centroid;
    
}SegmentNode;


class U11TriangleEntity {
    
private:
    
    VertexNode pointA;
    VertexNode pointB;
    VertexNode pointC;
    
    U4DEngine::U4DTriangle triangle;
     
public:
    
    U11TriangleEntity(VertexNode uPointA, VertexNode uPointB, VertexNode uPointC);
    
    ~U11TriangleEntity();
    
    std::vector<U4DEngine::U4DSegment> getTriangleEntitySegments();
    
    U4DEngine::U4DVector3n getTriangleEntityNormal();
    
    U4DEngine::U4DPoint3n getTriangleEntityCentroid();

//    TriangleNode &getTriangleNode();
//    
//    U4DEngine::U4DTriangle getTriangleGeometry();
//    

//    
//    std::vector<U11Player*> getThreatPlayersInsideTriangle();
//    
//    bool getIsTriangleEntitySafe();
    
};

#endif /* U11TriangleEntity_hpp */
