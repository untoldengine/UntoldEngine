//
//  U11SpaceAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/29/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11SpaceAnalyzer_hpp
#define U11SpaceAnalyzer_hpp

#include <stdio.h>
#include <vector>
#include "U4DVector3n.h"
#include "U4DSegment.h"

class U11Player;
class U11Team;


typedef struct{
    
    U4DEngine::U4DPoint3n position;
    bool goodAnglePass=false;
    bool assigned=false;
    
}SupportNode;

class U11SpaceAnalyzer {
    
private:
    
    std::vector<SupportNode> supportNodes;
    
public:
    
    U11SpaceAnalyzer();
    
    ~U11SpaceAnalyzer();
    
    std::vector<U11Player*> analyzePlayersDistanceToPosition(U11Team *uTeam, U4DEngine::U4DVector3n &uPosition);
    
    std::vector<U11Player*> analyzeClosestPlayersAlongLine(U11Team *uTeam, U4DEngine::U4DSegment &uLine);
    
    U4DEngine::U4DPoint3n analyzeClosestSupportSpaceAlongLine(U4DEngine::U4DVector3n &uLine, std::vector<SupportNode> &uSupportNodes, U4DEngine::U4DVector3n &uControllingPlayerPosition);
    
    std::vector<U4DEngine::U4DPoint3n> computeOptimalSupportSpace(U11Team *uTeam);
    
    U4DEngine::U4DPoint3n computeOptimalDefenseSpace(U11Team *uTeam);
    
};

#endif /* U11SpaceAnalyzer_hpp */
