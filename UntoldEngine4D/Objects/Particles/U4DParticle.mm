//
//  U4DParticles.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DParticle.h"
#include "U4DOpenGLParticle.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    U4DParticle::U4DParticle():animationElapseTime(0.0),numberOfParticles(50){
        
    }

    U4DParticle::~U4DParticle(){
        delete openGlManager;
    }
    
    void U4DParticle::draw(){
        
        openGlManager->draw();
        
    }
    
    void U4DParticle::setNumberOfParticles(int uNumberOfParticles){
        
        numberOfParticles=uNumberOfParticles;
        
    }
    
    int U4DParticle::getNumberOfParticles(){
     
        return numberOfParticles;
    }
    
    void U4DParticle::setAnimationElapseTime(float uAnimationElapseTime){
        
        animationElapseTime=uAnimationElapseTime;
    }
    

    void U4DParticle::setParticlesVertices(){
        
        //make a cube
        float width=0.5;
        float height=0.5;
        float depth=0.5;
        
        U4DVector3n v1(width,height,depth);
        U4DVector3n v2(width,height,-depth);
        U4DVector3n v3(-width,height,-depth);
        U4DVector3n v4(-width,height,depth);
        
        U4DVector3n v5(width,-height,depth);
        U4DVector3n v6(width,-height,-depth);
        U4DVector3n v7(-width,-height,-depth);
        U4DVector3n v8(-width,-height,depth);
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        U4DIndex i3(4,5,6);
        U4DIndex i4(6,7,4);
        
        U4DIndex i5(5,6,2);
        U4DIndex i6(2,3,7);
        U4DIndex i7(7,4,5);
        U4DIndex i8(5,1,0);
        
        particleCoordinates.addVerticesDataToContainer(v1);
        particleCoordinates.addVerticesDataToContainer(v2);
        particleCoordinates.addVerticesDataToContainer(v3);
        particleCoordinates.addVerticesDataToContainer(v4);
        
        particleCoordinates.addVerticesDataToContainer(v5);
        particleCoordinates.addVerticesDataToContainer(v6);
        particleCoordinates.addVerticesDataToContainer(v7);
        particleCoordinates.addVerticesDataToContainer(v8);
        
        particleCoordinates.addIndexDataToContainer(i1);
        particleCoordinates.addIndexDataToContainer(i2);
        particleCoordinates.addIndexDataToContainer(i3);
        particleCoordinates.addIndexDataToContainer(i4);
        
        particleCoordinates.addIndexDataToContainer(i5);
        particleCoordinates.addIndexDataToContainer(i6);
        particleCoordinates.addIndexDataToContainer(i7);
        particleCoordinates.addIndexDataToContainer(i8);
        
    }
    
    float U4DParticle::mix(float x, float y, float a){
        
        return (x*(1-a) + y*a);
    }
    
}
