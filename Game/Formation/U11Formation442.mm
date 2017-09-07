//
//  U11Formation424.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/1/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Formation442.h"
#include "U11FormationEntity.h"
#include "UserCommonProtocols.h"

U11Formation442::U11Formation442(){
    
}

U11Formation442::~U11Formation442(){
    
    delete leftBackDefense;
    delete centerLeftBackDefense;
    delete centerRightBackDefense;
    delete rightBackDefense;
    
    delete leftWing;
    delete leftMidfielder;
    delete rightMidfielder;
    delete rightWing;
    
    delete leftCenterForward;
    delete rightCenterForward;
    
    delete mainParent;
}

void U11Formation442::init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant){
    
    leftBackDefense=new U11FormationEntity();
    centerLeftBackDefense=new U11FormationEntity();
    centerRightBackDefense=new U11FormationEntity();
    rightBackDefense=new U11FormationEntity();
    
    leftWing=new U11FormationEntity();
    leftMidfielder=new U11FormationEntity();
    rightMidfielder=new U11FormationEntity();
    rightWing=new U11FormationEntity();
    
    leftCenterForward=new U11FormationEntity();
    rightCenterForward=new U11FormationEntity();
    
    mainParent=new U11FormationEntity();
    
    leftBackDefense->init("leftbackdefense", "formation442.u4d");
    centerLeftBackDefense->init("centerleftbackdefense", "formation442.u4d");
    centerRightBackDefense->init("centerrightbackdefense", "formation442.u4d");
    rightBackDefense->init("rightbackdefense", "formation442.u4d");
    
    leftWing->init("leftwing", "formation442.u4d");
    leftMidfielder->init("leftmidfielder", "formation442.u4d");
    rightMidfielder->init("rightmidfielder", "formation442.u4d");
    rightWing->init("rightwing", "formation442.u4d");
    
    leftCenterForward->init("leftcenterforward", "formation442.u4d");
    rightCenterForward->init("rightcenterforward", "formation442.u4d");
    
    mainParent->init("mainparent", "formation442.u4d");
    
    //make the formation entities children of the main parent
    mainParent->addChild(leftBackDefense);
    mainParent->addChild(centerLeftBackDefense);
    mainParent->addChild(centerRightBackDefense);
    mainParent->addChild(rightBackDefense);
    
    mainParent->addChild(leftWing);
    mainParent->addChild(leftMidfielder);
    mainParent->addChild(rightMidfielder);
    mainParent->addChild(rightWing);
    
    mainParent->addChild(leftCenterForward);
    mainParent->addChild(rightCenterForward);
    
    uWorld->addChild(mainParent);
    
    fieldQuadrant=uFieldQuadrant;
    
    U4DEngine::U4DVector3n axis(0.0,1.0,0.0);
    mainParent->rotateTo(fieldQuadrant*90.0, axis);
    
    mainParent->translateBy(fieldQuadrant*1.0, 0.0, 0.0);
    
    U4DEngine::U4DPoint3n min(-formationSpaceBoundaryLength/2.0,-1.0,-formationSpaceBoundaryWidth/2.0);
    U4DEngine::U4DPoint3n max(formationSpaceBoundaryLength/2.0,1.0,formationSpaceBoundaryWidth/2.0);
    
    formationAABB.setMaxPoint(max);
    formationAABB.setMinPoint(min);
}
