//
//  U4DPathAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPathAnalyzer.h"
#include "U4DFieldAnalyzer.h"
#include "U4DNavMesh.h"
#include "U4DPoint3n.h"
#include "U4DAABB.h"
#include "Constants.h"
#include "U4DGameConfigs.h"
#include "U4DMatchManager.h"
#include "U4DGoalPost.h"

namespace U4DEngine {

U4DPathAnalyzer* U4DPathAnalyzer::instance=0;

U4DPathAnalyzer::U4DPathAnalyzer(){
    
    //load the navigation mesh data
    navigationSystem=new U4DEngine::U4DNavigation();
    
    if(navigationSystem->loadNavMesh("soccerNavMesh","voxelfieldNavMesh.u4d")){
        
        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
        
        //set parameters here
        navigationSystem->setPathRadius(gameConfigs->getParameterForKey("navPathRadius"));
        navigationSystem->setPredictTime(gameConfigs->getParameterForKey("navPredictTime"));
        navigationSystem->setNavigationSpeed(gameConfigs->getParameterForKey("dribblingBallSpeed"));
        navigationSystem->setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
        navigationSystem->setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));
        
    }
    
    
}

U4DPathAnalyzer::~U4DPathAnalyzer(){
    delete navigationSystem;
}

U4DPathAnalyzer* U4DPathAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new U4DPathAnalyzer();
        
    }
    
    return instance;
}

void U4DPathAnalyzer::computeNavigation(U4DPlayer *uPlayer){
    
    //update the navmesh nodes weights
    U4DFieldAnalyzer *fieldAnalyzer=U4DFieldAnalyzer::sharedInstance();
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    U4DMatchManager *matchManager=U4DMatchManager::sharedInstance();
    
    U4DEngine::U4DNavMesh *navMesh=navigationSystem->getNavMesh();
    
    float fieldWidthCell=gameConfigs->getParameterForKey("cellAnalyzerWidth");
    float fieldHeightCell=gameConfigs->getParameterForKey("cellAnalyzerHeight");
    
    for(int i=0;i<navMesh->getNavMeshNodeContainer().size();i++){
        
        U4DEngine::U4DNavMeshNode &navNode=navMesh->getNodeAt(i);
        
        U4DEngine::U4DVector2n pos(navNode.position.x,navNode.position.z);
        
        pos.x=floor(pos.x/fieldWidthCell);
        pos.y=ceil(pos.y/fieldHeightCell);
        
        
        //get the cell influence
        float cellInfluence=fieldAnalyzer->getCell(pos).influence;
        
        navNode.weight=cellInfluence;
        
    }
    
    //get the closest point to the goal post and steer towards it
    
    U4DGoalPost *goalPost=matchManager->getTeamBGoalPost();
    
    U4DEngine::U4DAABB aabb=goalPost->goalBoxAABB;
    
    U4DEngine::U4DPoint3n pos=uPlayer->getAbsolutePosition().toPoint();
    
    U4DEngine::U4DPoint3n closestPoint;
    
    aabb.closestPointOnAABBToPoint(pos, closestPoint);
    
    uPlayer->navDribbling=closestPoint.toVector();
    U4DEngine::U4DVector3n targetPosition=closestPoint.toVector();

    navigationSystem->computePath(uPlayer->kineticAction, targetPosition);
    
    navigationPath=navigationSystem->getNavPath();
    
}

U4DEngine::U4DVector3n U4DPathAnalyzer::desiredNavigationVelocity(U4DPlayer *uPlayer){

    
    return navigationSystem->getSteering(uPlayer->kineticAction);

}

std::vector<U4DEngine::U4DSegment> U4DPathAnalyzer::getNavigationPath(){
    
    return navigationPath;

}


}

