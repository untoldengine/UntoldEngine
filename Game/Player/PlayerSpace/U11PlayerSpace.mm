//
//  U11PlayerSpace.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerSpace.h"

U11PlayerSpace::U11PlayerSpace(){
    
}

U11PlayerSpace::~U11PlayerSpace(){
    
}

void U11PlayerSpace::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        setShader("vertexNonVisibleShader","fragmentNonVisibleShader");
        
        setEntityType(U4DEngine::MODELNOSHADOWS);
        
//        initMass(0.0);
//        initAsPlatform(true);
//        initCoefficientOfRestitution(0.0);
//        enableCollisionBehavior();
        
//        setCollisionFilterCategory(kU11PlayerExtremity);
//        setCollisionFilterMask(kU11Ball);
//        
//        //set player collision with ball filter to occur
//        setCollisionFilterGroupIndex(kPlayerExtremitiesGroupIndex);
//
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        //set up the player space box
        //Get body dimensions
        float xDimension=bodyCoordinates.getModelDimension().x;
        float yDimension=bodyCoordinates.getModelDimension().y;
        float zDimension=bodyCoordinates.getModelDimension().z;
        
        //get min and max points to create the AABB
        U4DEngine::U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
        U4DEngine::U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
        
        playerSpaceBox.setMinPoint(minPoints);
        playerSpaceBox.setMaxPoint(maxPoints);
        
        loadRenderingInformation();
        
    }
}

void U11PlayerSpace::update(double dt){
    
}

U4DEngine::U4DAABB U11PlayerSpace::getUpdatedPlayerSpaceBox(){
    
    U4DEngine::U4DPoint3n minPoint=playerSpaceBox.getMinPoint();
    U4DEngine::U4DPoint3n maxPoint=playerSpaceBox.getMaxPoint();
    
    U4DEngine::U4DPoint3n position=getAbsolutePosition().toPoint();
    
    position.y=0;
    
    minPoint+=position;
    maxPoint+=position;
    
    return U4DEngine::U4DAABB(minPoint,maxPoint);
    
}
