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
#include "U4DAABB.h"
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
    U4DEngine::U4DAABB playingField;
    
public:
    
    U11SpaceAnalyzer();
    
    ~U11SpaceAnalyzer();
    
    std::vector<U11Player*> analyzePlayersDistanceToPosition(U11Team *uTeam, U4DEngine::U4DVector3n &uPosition);
    
    std::vector<U11Player*> analyzeClosestPlayersAlongLine(U11Team *uTeam, U4DEngine::U4DSegment &uLine);
    
    U4DEngine::U4DPoint3n analyzeClosestSupportSpaceAlongLine(U4DEngine::U4DVector3n &uLine, std::vector<SupportNode> &uSupportNodes, U4DEngine::U4DVector3n &uControllingPlayerPosition);
    
    std::vector<U4DEngine::U4DPoint3n> computeOptimalSupportSpace(U11Team *uTeam);
    
    U4DEngine::U4DPoint3n computeMovementRelToFieldGoal(U11Team *uTeam, U11Player *uPlayer, float uDistance);
    
    std::vector<U11Player*> analyzeThreateningPlayers(U11Team *uTeam);
    
    U11Player *getDefensePlayerClosestToThreatingPlayer(U11Team *uTeam, U11Player *uThreateningPlayer);
    
    std::vector<U11Player*> analyzeSupportPlayers(U11Team *uTeam);
    
    std::vector<U11Player*> analyzeDefendingPlayer(U11Team *uTeam);
    
    std::vector<U11Player*> analyzeClosestPlayersToBall(U11Team *uTeam);
    
    std::vector<U11Player*> analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition, U11Team *uTeam);
    
    std::vector<U11Player*> analyzeClosestPlayersAlongPassLine(U11Team *uTeam);
    
};

#endif /* U11SpaceAnalyzer_hpp */
