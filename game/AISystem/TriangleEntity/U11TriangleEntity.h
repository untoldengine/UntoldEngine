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
#include "U11Player.h"

class U11Player;
class U11TriangleEntity;

typedef struct{
    
    U11Player* player;
    U4DEngine::U4DPoint3n optimalPosition;
    
}VertexNode;


typedef struct{
    
    VertexNode nodeA;
    VertexNode nodeB;
    U4DEngine::U4DSegment segment;
    U4DEngine::U4DPoint3n centroid;
    U11TriangleEntity *segmentParent;
    
}SegmentNode;


class U11TriangleEntity {
    
private:
    
    VertexNode vertexNodeA;
    VertexNode vertexNodeB;
    VertexNode vertexNodeC;
    
    U4DEngine::U4DTriangle triangleGeometry;
    
public:
    
    U11TriangleEntity();
    
    U11TriangleEntity(VertexNode uVertexNodeA, VertexNode uVertexNodeB, VertexNode uVertexNodeC);
    
    ~U11TriangleEntity();
    
    std::vector<U4DEngine::U4DSegment> getTriangleEntitySegments();
    
    std::vector<U11Player*> getTriangleEntityPlayers();
    
    U4DEngine::U4DVector3n getTriangleEntityNormal();
    
    U4DEngine::U4DPoint3n getTriangleEntityCentroid();
    
    U4DEngine::U4DTriangle getTriangleEntityGeometry();
    
    U11TriangleEntity *parent;
    
    U11TriangleEntity *prevSibling;
    
    U11TriangleEntity *next;
    
    U11TriangleEntity *lastDescendant;
    
    U11TriangleEntity *getFirstChild();
    
    U11TriangleEntity *getLastChild();
    
    U11TriangleEntity *getNextSibling();
    
    U11TriangleEntity *getPrevSibling();
    
    U11TriangleEntity *prevInPreOrderTraversal();
    
    U11TriangleEntity *nextInPreOrderTraversal();
    
    void addChild(U11TriangleEntity *uChild);
    
    void removeChild(U11TriangleEntity *uChild);
    
    void changeLastDescendant(U11TriangleEntity *uNewLastDescendant);
    
    bool isLeaf();
    
    bool isRoot();
    

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
