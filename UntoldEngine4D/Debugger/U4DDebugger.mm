//
//  U4DDebugger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DDebugger.h"
#include "U4DOpenGLDebugger.h"

namespace U4DEngine {
    
U4DDebugger::U4DDebugger(){
    
    openGlManager=new U4DOpenGLDebugger(this);
    openGlManager->setShader("debugShader");
    
    buildEntityAxis();
    
}

void U4DDebugger::draw(){
    
    openGlManager->draw();

}

void U4DDebugger::addEntityToDebug(U4DEntity *uEntity){
    
    entityContainer.push_back(uEntity);
    
}

void U4DDebugger::buildEntityAxis(){
    
    //origin
    U4DVector3n origin(0,0,0);
    
    //x-axis
    U4DVector3n xAxis(3,0,0);
    
    //y-axis
    U4DVector3n yAxis(0,3,0);
    
    //z-axis
    U4DVector3n zAxis(0,0,3);
    
    bodyCoordinates.addVerticesDataToContainer(origin);
    bodyCoordinates.addVerticesDataToContainer(xAxis);
    
    bodyCoordinates.addVerticesDataToContainer(origin);
    bodyCoordinates.addVerticesDataToContainer(yAxis);
    
    bodyCoordinates.addVerticesDataToContainer(origin);
    bodyCoordinates.addVerticesDataToContainer(zAxis);
}

}