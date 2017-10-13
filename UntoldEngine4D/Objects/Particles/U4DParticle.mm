//
//  U4DParticle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticle.h"
#include "U4DRenderParticle.h"
#include "U4DVector3n.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DParticle::U4DParticle():particleAnimationElapsedTime(0.0),numberOfParticles(50),diffuseColor(1.0,0.0,0.0,1.0),hasTexture(false),particleLifeTime(50){
        
        renderManager=new U4DRenderParticle(this);
        
        setShader("vertexParticleShader", "fragmentParticleShader");
    }
    
    U4DParticle::~U4DParticle(){
        
        delete renderManager;
        
    }
    
    void U4DParticle::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DParticle::setNumberOfParticles(int uNumberOfParticles){
        
        numberOfParticles=uNumberOfParticles;
        
    }
    
    int U4DParticle::getNumberOfParticles(){
        
        return numberOfParticles;
    }
    
    
    void U4DParticle::setParticleTexture(const char* uTextureImage){
        
        renderManager->setDiffuseTexture(uTextureImage);
        
    }
    
    void U4DParticle::setParticlesVertices(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //make a rectangle
        float width=0.1;
        float height=0.1;
        float depth=0.0;
        
        //vertices
        U4DEngine::U4DVector3n v1(width,height,depth);
        U4DEngine::U4DVector3n v4(width,-height,depth);
        U4DEngine::U4DVector3n v2(-width,-height,depth);
        U4DEngine::U4DVector3n v3(-width,height,depth);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v4);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        
        //texture
        U4DEngine::U4DVector2n t4(0.0,0.0);  //top left
        U4DEngine::U4DVector2n t1(1.0,0.0);  //top right
        U4DEngine::U4DVector2n t3(0.0,1.0);  //bottom left
        U4DEngine::U4DVector2n t2(1.0,1.0);  //bottom right
        
        bodyCoordinates.addUVDataToContainer(t1);
        bodyCoordinates.addUVDataToContainer(t2);
        bodyCoordinates.addUVDataToContainer(t3);
        bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DEngine::U4DIndex i1(0,1,2);
        U4DEngine::U4DIndex i2(2,3,0);
        
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
    
    }
    
    float U4DParticle::getParticleAnimationElapsedTime(){
        
        return particleAnimationElapsedTime;
        
    }
    
    void U4DParticle::setDiffuseColor(U4DVector4n &uDiffuseColor){
        
        diffuseColor=uDiffuseColor;
        
    }
    
    U4DVector4n U4DParticle::getDiffuseColor(){
        
        return diffuseColor;
    }
    
    void U4DParticle::setHasTexture(bool uValue){
        
        hasTexture=uValue;
    }
    
    bool U4DParticle::getHasTexture(){
        
        return hasTexture;
        
    }
    
    void U4DParticle::setParticleLifetime(int uLifetime){
        
        particleLifeTime=uLifetime;
        
    }
    
    int U4DParticle::getParticleLifetime(){
        
        return particleLifeTime;
        
    }
    
}

