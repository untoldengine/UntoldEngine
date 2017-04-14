//
//  U11FieldGoal.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11FieldGoal.h"

U11FieldGoal::U11FieldGoal(){
    
}

U11FieldGoal::~U11FieldGoal(){
    
}

void U11FieldGoal::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        //setShader("nonVisibleShader");
        
        computeFieldGoalWidthSegment();
        
        loadRenderingInformation();
        
    }
    
}

void U11FieldGoal::update(double dt){
    
}

void U11FieldGoal::computeFieldGoalWidthSegment(){
    
    float zDimension=bodyCoordinates.getModelDimension().z;
    
    U4DEngine::U4DVector3n position=getAbsolutePosition();
    
    //get A and B points to create segment
    U4DEngine::U4DPoint3n pointA(position.x,0.0,-zDimension/2.0);
    U4DEngine::U4DPoint3n pointB(position.x,0.0,zDimension/2.0);
    
    fieldGoalWidthSegment.pointA=pointA;
    fieldGoalWidthSegment.pointB=pointB;
}

U4DEngine::U4DSegment U11FieldGoal::getFieldGoalWidthSegment(){
    
    return fieldGoalWidthSegment;
    
}
