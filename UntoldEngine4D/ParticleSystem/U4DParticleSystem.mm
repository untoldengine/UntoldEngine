//
//  U4DParticleSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleSystem.h"
#include "U4DRenderParticleSystem.h"
#include "U4DNumerical.h"
#include "U4DTrigonometry.h"
#include "U4DParticlePhysics.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"
#include "CommonProtocols.h"
#include "U4DCamera.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DParticleSystem::U4DParticleSystem():maxNumberOfParticles(50),hasTexture(false),enableAdditiveRendering(true),enableNoise(false),noiseDetail(4.0){
        
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
        
        U4DVector3n particleSystemPosition=getAbsolutePosition();

        U4DEntity *child=this->getLastChild();
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        
        //face the camera
        U4DVector3n cameraPosition=camera->getAbsolutePosition();

        viewInDirection(cameraPosition);
        
        while (child!=nullptr) {

            U4DParticle *particle=dynamic_cast<U4DParticle*>(child);

            if (particle) {

                if(particle->particleData.life>0.0){

                    //update particle information
                    particlePhysics->updateForce(particleSystemPosition,particle,dt);
                    
                    particlePhysics->integrate(particle, dt);
                    
                    //update color
                    particle->particleData.color=particle->particleData.color+particle->particleData.deltaColor*dt;
                    
                    //update size
                    particle->particleData.particleSize=particle->particleData.particleSize+particle->particleData.deltaParticleSize*dt;
                    
                    particle->particleData.particleScaleFactor=particle->particleData.particleSize/particle->particleData.startParticleSize;
                    
                    //update rotation. Note the delta particle is multiplied twice with the dt to make the rotation a lot slower.
                    particle->particleData.particleRotation=particle->particleData.particleRotation+particle->particleData.deltaParticleRotation*dt*dt;
                    
                    //load the info of the particle into the vector
                    PARTICLERENDERDATA particleRenderData;

                    //set color
                    particleRenderData.color=particle->particleData.color;
                    
                   //set space
                    particleRenderData.absoluteSpace=(particle->getLocalSpace()*particle->getParent()->getAbsoluteSpace()).transformDualQuaternionToMatrix4n();
                    
                    //set size scale
                    particleRenderData.scaleFactor=particle->particleData.particleScaleFactor;
                    
                    //set rotation
                    particleRenderData.rotationAngle=particle->particleData.particleRotation;
                    
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
    
    bool U4DParticleSystem::loadParticleSystem(const char* uParticleAssetFile, const char* uParticleTextureFile){
        
        if(particleLoader.loadParticleAssetFile(uParticleAssetFile)){
            
            setParticleDimension(particleLoader.particleSystemData.startParticleSize,particleLoader.particleSystemData.startParticleSize);
            
            renderManager->setDiffuseTexture(uParticleTextureFile);
            
            //max number of particles
            maxNumberOfParticles=particleLoader.particleSystemData.maxNumberOfParticles;
        
            //blending factors
            blendingFactorSource=particleLoader.particleSystemData.blendingFactorSource;
            blendingFactorDest=particleLoader.particleSystemData.blendingFactorDest;
            
            //initialize particle emitter
            initializeParticleEmitter(particleLoader.particleSystemData);
            
            return true;
        }
        
        return false;
        
        
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
            particleData.speedVariance=uParticleSystemData.particleSpeedVariance;
            
            //gravity
            particleData.gravity=uParticleSystemData.gravity;
            
            //radial acceleration
            particleData.particleRadialAcceleration=uParticleSystemData.particleRadialAcceleration;
            particleData.particleRadialAccelerationVariance=uParticleSystemData.particleRadialAccelerationVariance;
            
            //tangential acceleration
            particleData.particleTangentialAcceleration=uParticleSystemData.particleTangentialAcceleration;
            particleData.particleTangentialAccelerationVariance=uParticleSystemData.particleTangentialAccelerationVariance;
            
            //life
            particleData.life=uParticleSystemData.particleLife;
            
            //start size
            particleData.startParticleSize=uParticleSystemData.startParticleSize;
            
            //start size variance
            particleData.startParticleSizeVariance=uParticleSystemData.startParticleSizeVariance;
            
            //end size
            particleData.endParticleSize=uParticleSystemData.endParticleSize;
            
            //end size variance
            particleData.endParticleSizeVariance=uParticleSystemData.endParticleSizeVariance;
            
            //start rotation
            particleData.startParticleRotation=uParticleSystemData.startParticleRotation;
            
            //start rotation variance
            particleData.startParticleRotationVariance=uParticleSystemData.startParticleRotationVariance;
            
            //end rotation
            particleData.endParticleRotation=uParticleSystemData.endParticleRotation;
            
            //end rotation variance
            particleData.endParticleRotationVariance=uParticleSystemData.endParticleRotationVariance;
            
            //particles per emission
            particleEmitter->setNumberOfParticlesPerEmission(uParticleSystemData.numberOfParticlesPerEmission);
            
            //emit continuously
            particleEmitter->setEmitContinuously(uParticleSystemData.emitContinuously);
            
            //emission rate
            particleEmitter->setParticleEmissionRate(uParticleSystemData.emissionRate);
            
            //emission duration rate
            particleEmitter->setEmitterDurationRate(uParticleSystemData.emitterDurationRate);
            
            //torus major radius
            particleData.torusMajorRadius=uParticleSystemData.torusMajorRadius;
            
            //torus minor radius
            particleData.torusMinorRadius=uParticleSystemData.torusMinorRadius;
            
            //sphere radius
            particleData.sphereRadius=uParticleSystemData.sphereRadius;
            
            particleEmitter->setParticleSystem(this);
            
            particleEmitter->setParticleData(particleData);
            
        }
        
    }
    
    void U4DParticleSystem::play(){
        particleEmitter->play();
    }
    
    void U4DParticleSystem::stop(){
        
        particleEmitter->stop();
        
        removeAllParticles();
        
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
    
    bool U4DParticleSystem::getEnableAdditiveRendering(){
        
        return enableAdditiveRendering;
    }
    
    bool U4DParticleSystem::getEnableNoise(){
        
        return enableNoise;
    }
    
    float U4DParticleSystem::getNoiseDetail(){
        
        return noiseDetail;
    }
    
    void U4DParticleSystem::setParticleDimension(float uWidth,float uHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //make a rectangle
        float width=uWidth/director->getDisplayWidth();
        float height=uHeight/director->getDisplayHeight();
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
    
    U4DVector3n U4DParticleSystem::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getEntityForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DParticleSystem::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        U4DVector3n entityPosition;
        float oneEightyAngle=180.0;
        
        //Get the absolute position
        entityPosition=getAbsolutePosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //create a forward vector that is in the same y-plane as the entity forward vector
        U4DVector3n altPlaneForwardVector=forwardVector;
        
        altPlaneForwardVector.y=getEntityForwardVector().y;
        
        //normalize both vectors
        forwardVector.normalize();
        altPlaneForwardVector.normalize();
        
        //calculate the angle between the entity forward vector and the alternate forward vector
        float angleBetweenEntityForwardAndAltForward=getEntityForwardVector().angle(altPlaneForwardVector);
        
        //calculate the rotation axis between forward vectors
        U4DVector3n rotationAxisOfEntityAndAltForward=getEntityForwardVector().cross(altPlaneForwardVector);
        
        //if angle is 180 or -180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        //Get the absolute value of the angle, so we can properly test it.
        float nAngle=fabs(angleBetweenEntityForwardAndAltForward);
        
        if ((fabs(nAngle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(nAngle, zeroEpsilon)))) {
            
            rotationAxisOfEntityAndAltForward=upVector;
            angleBetweenEntityForwardAndAltForward=180.0;
            
        }
        
        rotationAxisOfEntityAndAltForward.normalize();
        
        U4DQuaternion rotationAboutEntityAndAltForward(angleBetweenEntityForwardAndAltForward, rotationAxisOfEntityAndAltForward);
        
        rotateTo(rotationAboutEntityAndAltForward);
        
        //calculate the angle between the forward vector and the alternate forward vector
        float angleBetweenForwardVectorAndAltForward=forwardVector.angle(altPlaneForwardVector);
        
        //calculate the rotation axis between the forward vectors
        U4DVector3n rotationAxisOfForwardVectorAndAltForward=altPlaneForwardVector.cross(forwardVector);
        
        rotationAxisOfForwardVectorAndAltForward.normalize();
        
        U4DQuaternion rotationAboutForwardVectorAndAltForward(angleBetweenForwardVectorAndAltForward,rotationAxisOfForwardVectorAndAltForward);
        
        rotateBy(rotationAboutForwardVectorAndAltForward);
        
    }
    
    int U4DParticleSystem::getBlendingFactorSource(){
        return blendingFactorSource;
    }
    
    int U4DParticleSystem::getBlendingFactorDest(){
        return blendingFactorDest;
    }
    
    void U4DParticleSystem::setEnableAdditiveRendering(bool uValue){
        enableAdditiveRendering=uValue;
    }
    
    void U4DParticleSystem::setEnableNoise(bool uValue){
        enableNoise=uValue;
    }
    
    void U4DParticleSystem::setNoiseDetail(float uNoiseDetail){
        noiseDetail=uNoiseDetail;
    }
    
}
