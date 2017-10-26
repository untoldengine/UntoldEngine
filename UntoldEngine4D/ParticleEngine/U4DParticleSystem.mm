//
//  U4DParticleSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticleSystem.h"
#include "U4DRenderParticleSystem.h"
#include "U4DNumerical.h"
#include "U4DTrigonometry.h"
#include "U4DParticlePhysics.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"


namespace U4DEngine {
    
    U4DParticleSystem::U4DParticleSystem():maxNumberOfParticles(50),hasTexture(false),gravity(0.0,-5.0,0.0){
        
        renderManager=new U4DRenderParticleSystem(this);
        
        setShader("vertexParticleSystemShader", "fragmentParticleSystemShader");
        
        particlePhysics=new U4DParticlePhysics();
        
        particleEmitter=nullptr;
        
    }
    
    U4DParticleSystem::~U4DParticleSystem(){
        
        delete particleEmitter;

        delete particlePhysics;
        
        removeAllParticles();
        
    }
    
    void U4DParticleSystem::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DParticleSystem::update(double dt){
        
        particleRenderDataContainer.clear();

        U4DEntity *child=this->getLastChild();

        while (child!=nullptr) {

            U4DParticle *particle=dynamic_cast<U4DParticle*>(child);

            if (particle) {

                if(particle->particleData.life>0.0){

                    //update particle information
                    particlePhysics->updateForce(particle,gravity,dt);
                    
                    particlePhysics->integrate(particle, dt);
                    
                    particle->particleData.color=particle->particleData.color+particle->particleData.deltaColor*dt;

                    //load the info of the particle into the vector
                    PARTICLERENDERDATA particleRenderData;

                    particleRenderData.color=particle->particleData.color;

                    particleRenderData.absoluteSpace=particle->getAbsoluteSpace().transformDualQuaternionToMatrix4n();

                    particleRenderDataContainer.push_back(particleRenderData);

                    particle->particleData.life=particle->particleData.life-dt;

                    particle->clearForce();
                    
                }else{

                    //particle is dead
                
                    particleEmitter->decreaseNumberOfEmittedParticles();

                    //remove the node from the scenegraph
                    removeParticleContainer.push_back(particle);

                }

            }

            child=child->getPrevSibling();

        }

        removeDeadParticle();
    }
    
    void U4DParticleSystem::init(PARTICLESYSTEMDATA &uParticleSystemData){
        
        setParticleTexture(uParticleSystemData.texture);
        
        initParticleAttributes();
        
        loadRenderingInformation();
        
        initializeParticleEmitter(uParticleSystemData);
        
    }
    
    void U4DParticleSystem::initializeParticleEmitter(PARTICLESYSTEMDATA &uParticleSystemData){
        
        //get the particle emitter
        
        particleEmitter=emitterFactory.createEmitter(uParticleSystemData.particleSystemType);
        
        if (particleEmitter!=nullptr) {
            
            U4DParticleData particleData;
            
            //color
            particleData.startColor=uParticleSystemData.particleStartColor;
            particleData.startColorVariance=uParticleSystemData.particleStartColorVariance;
            
            particleData.endColor=uParticleSystemData.particleEndColor;
            particleData.endColorVariance=uParticleSystemData.particleEndColorVariance;
            
            //position
            particleData.positionVariance=uParticleSystemData.particlePositionVariance;
            
            //angle
            particleData.emitAngle=uParticleSystemData.particleEmitAngle;
            particleData.emitAngleVariance=uParticleSystemData.particleEmitAngleVariance;
            
            //speed
            particleData.speed=uParticleSystemData.particleSpeed;
            
            //life
            particleData.life=uParticleSystemData.particleLife;
            
            
            maxNumberOfParticles=uParticleSystemData.maxNumberOfParticles;
            
            gravity=uParticleSystemData.gravity;
            
            particleEmitter->setNumberOfParticlesPerEmission(uParticleSystemData.numberOfParticlesPerEmission);
            
            particleEmitter->setEmitContinuously(uParticleSystemData.emitContinuously);
            
            particleEmitter->setParticleEmissionRate(uParticleSystemData.emissionRate);
            
            
            particleEmitter->setParticleSystem(this);
            
            particleEmitter->setParticleData(particleData);
            
            particleEmitter->initialize();
            
        }
        
    }
    
    void U4DParticleSystem::initParticleAttributes(){
        
       //make a rectangle
        float width=0.5;
        float height=0.5;
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
    
    void U4DParticleSystem::setMaxNumberOfParticles(int uMaxNumberOfParticles){
        
        maxNumberOfParticles=uMaxNumberOfParticles;
        
    }
    
    int U4DParticleSystem::getMaxNumberOfParticles(){
        
        return maxNumberOfParticles;
    }
    
    
    int U4DParticleSystem::getNumberOfEmittedParticles(){
        
        return particleEmitter->getNumberOfEmittedParticles();
    }
    
    void U4DParticleSystem::setParticleTexture(const char* uTextureImage){
        
        renderManager->setDiffuseTexture(uTextureImage);
        
    }
    
    void U4DParticleSystem::setHasTexture(bool uValue){
        
        hasTexture=uValue;
    }
    
    bool U4DParticleSystem::getHasTexture(){
        
        return hasTexture;
        
    }
    
    std::vector<PARTICLERENDERDATA> U4DParticleSystem::getParticleRenderDataContainer(){
        
        return particleRenderDataContainer;
        
    }
    
    void U4DParticleSystem::removeDeadParticle(){

        //remove node from tree
        for(auto n:removeParticleContainer){
            
            U4DEntity *parent=n->getParent();
            
            parent->removeChild(n);
            
        }
        
        //destruct the object
        for (int i=0; i<removeParticleContainer.size(); i++) {
            
            delete removeParticleContainer.at(i);
            
        }
        
        removeParticleContainer.clear();
        
    }
    
    void U4DParticleSystem::removeAllParticles(){
        
        U4DEntity *child=this->getLastChild();
        
        while (child!=nullptr) {
            
            U4DParticle *particle=dynamic_cast<U4DParticle*>(child);
            
            if (particle) {
                
                removeParticleContainer.push_back(particle);
                
            }
            
            child=child->getPrevSibling();
        }
        
        removeDeadParticle();
        
    }
    
}
