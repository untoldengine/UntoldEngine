//
//  PathAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PathAnalyzer.h"
#include "FieldAnalyzer.h"
#include "U4DNavMesh.h"
#include "U4DPoint3n.h"

PathAnalyzer* PathAnalyzer::instance=0;

PathAnalyzer::PathAnalyzer(){
    
    //load the navigation mesh data
    navigationSystem=new U4DEngine::U4DNavigation();
    
    if(navigationSystem->loadNavMesh("Navmesh","fieldNavAttributes.u4d")){
        
        //set parameters here
        navigationSystem->setPathRadius(0.5);
        navigationSystem->setPredictTime(0.8);
        navigationSystem->setNavigationSpeed(10.0); 
        
    }
    
    
}

PathAnalyzer::~PathAnalyzer(){
    
}

PathAnalyzer* PathAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new PathAnalyzer();
        
    }
    
    return instance;
}

void PathAnalyzer::computeNavigation(Player *uPlayer){
    
    //update the navmesh nodes weights
    FieldAnalyzer *fieldAnalyzer=FieldAnalyzer::sharedInstance();
    
    U4DEngine::U4DNavMesh *navMesh=navigationSystem->getNavMesh();
    
    for(int i=0;i<navMesh->getNavMeshNodeContainer().size();i++){
        
        U4DEngine::U4DNavMeshNode &navNode=navMesh->getNodeAt(i);
        
        U4DEngine::U4DVector2n pos(navNode.position.x,navNode.position.z);
        
        pos.x=floor(pos.x/8.0);
        pos.y=ceil(pos.y/4.7);
        
        //get the cell influence
        float cellInfluence=fieldAnalyzer->getCell(pos).influence;
        
        navNode.weight=cellInfluence;
        
    }
    
    U4DEngine::U4DVector3n targetPosition(75.0,0.0,0.0);

    navigationSystem->computePath(uPlayer, targetPosition);
    
    navigationPath=navigationSystem->getNavPath();
    
}

U4DEngine::U4DVector3n PathAnalyzer::desiredNavigationVelocity(){

    //return navigationSystem->getSteering(player);

}

std::vector<U4DEngine::U4DSegment> PathAnalyzer::getNavigationPath(){
    
    return navigationPath;

}
