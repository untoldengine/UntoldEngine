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

typedef struct{
    
    U4DEngine::U4DPoint3n position;
    bool safeDribblingSpace=false;
    bool assigned=false;
    
}DribblingNode;

class U11SpaceAnalyzer {
    
private:
    
    std::vector<SupportNode> supportNodes;
    
    std::vector<DribblingNode> dribblingNodes;
    
    U4DEngine::U4DAABB playingField;
    
public:
    
    U11SpaceAnalyzer();
    
    ~U11SpaceAnalyzer();
    
    std::vector<U11Player*> getPlayersClosestToPosition(U11Team *uTeam, U4DEngine::U4DVector3n &uPosition);
    
    std::vector<U11Player*> getPlayersClosestToLine(U11Team *uTeam, U4DEngine::U4DSegment &uLine);
    
    std::vector<U11Player*> getClosestSupportPlayers(U11Team *uTeam);
    
    std::vector<U11Player*> getClosestDefendingPlayers(U11Team *uTeam);
    
    std::vector<U11Player*> getPlayersClosestToPassLine(U11Team *uTeam);
    
    std::vector<U11Player*> getClosestPlayersToBall(U11Team *uTeam);
    
    std::vector<U11Player*> analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition, U11Team *uTeam);
    
    std::vector<U11Player*> analyzeClosestPlayersAlongPassLine(U11Team *uTeam);
    
    U4DEngine::U4DPoint3n computeMovementRelToFieldGoal(U11Team *uTeam, U11Player *uPlayer, float uDistance);
    
    U4DEngine::U4DPoint3n getClosestSupportSpaceAlongLine(U4DEngine::U4DVector3n &uLine, std::vector<SupportNode> &uSupportNodes, U4DEngine::U4DVector3n &uControllingPlayerPosition);
    
    U4DEngine::U4DVector3n getClosestDribblingVectorTowardsGoal(std::vector<DribblingNode> &uDribblingNodes, U4DEngine::U4DVector3n &uPlayerToGoalVector, U4DEngine::U4DVector3n &uControllingPlayerPosition);
    
    std::vector<U4DEngine::U4DPoint3n> computeOptimalSupportSpace(U11Team *uTeam);
    
    U4DEngine::U4DVector3n computeOptimalDribblingVector(U11Team *uTeam);
    
    U11Player *getDefensePlayerClosestToThreatPlayer(U11Team *uTeam, U11Player *uThreatPlayer);
    
    int getNumberOfThreateningPlayers(U11Team *uTeam, U11Player *uPlayer);
    
    bool analyzeIfPlayerIsCloserToGoalThanMainPlayer(U11Team *uTeam, U11Player *uPlayer);
    
};

#endif /* U11SpaceAnalyzer_hpp */
