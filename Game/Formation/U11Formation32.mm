//
//  U11Formation32.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Formation32.h"
#include "U11FormationEntity.h"

U11Formation32::U11Formation32(){
    
}

U11Formation32::~U11Formation32(){
    
    delete leftDefense;
    delete rightDefense;
    delete centerMid;
    delete leftForward;
    delete rightForward;
    delete mainParent;
}

void U11Formation32::init(U4DEngine::U4DWorld *uWorld, int uFieldQuadrant){
 
    leftDefense=new U11FormationEntity();
    rightDefense=new U11FormationEntity();
    centerMid=new U11FormationEntity();
    leftForward=new U11FormationEntity();
    rightForward=new U11FormationEntity();
    mainParent=new U11FormationEntity();
    
    leftDefense->init("leftdefense", "formation32.u4d");
    rightDefense->init("rightdefense", "formation32.u4d");
    centerMid->init("centermid", "formation32.u4d");
    leftForward->init("leftforward", "formation32.u4d");
    rightForward->init("rightforward", "formation32.u4d");
    
    mainParent->init("mainparent", "formation32.u4d");
    
    //make the formation entities children of the main parent
    mainParent->addChild(leftDefense);
    mainParent->addChild(rightDefense);
    mainParent->addChild(leftForward);
    mainParent->addChild(rightForward);
    mainParent->addChild(centerMid);
    
    uWorld->addChild(mainParent);
    
    fieldQuadrant=uFieldQuadrant;
    
    U4DEngine::U4DVector3n axis(0.0,1.0,0.0);
    mainParent->rotateTo(fieldQuadrant*90.0, axis);
    
    mainParent->translateBy(fieldQuadrant*120.0, 0.0, 0.0);
    
}
