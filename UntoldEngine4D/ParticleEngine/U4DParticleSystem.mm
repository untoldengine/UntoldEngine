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


namespace U4DEngine {
    
    U4DParticleSystem::U4DParticleSystem():maxNumberOfParticles(50),emittedNumberOfParticles(0),hasTexture(false){
        
        renderManager=new U4DRenderParticleSystem(this);
        
        setShader("vertexParticleSystemShader", "fragmentParticleSystemShader");
        
        scheduler=new U4DCallback<U4DParticleSystem>;
        
        timer=new U4DTimer(scheduler);
    }
    
    U4DParticleSystem::~U4DParticleSystem(){
        
    }
    
    void U4DParticleSystem::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DParticleSystem::update(double dt){
        
        particleContainer.clear();
        
        U4DEntity *child=this->getLastChild();
        
        while (child!=nullptr) {
            
            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);
            
            if (model) {
                
                if(model->particleData.life>0.0){
                    
                    //update particle information
                    model->particleData.color=model->particleData.color+model->particleData.deltaColor*dt;
                    
                    //load the info of the particle into the vector
                    PARTICLEDATA particleData;
                    
                    particleData.color=model->particleData.color;
                    
                    particleData.absoluteSpace=model->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
                    
                    particleContainer.push_back(particleData);
                    
                    model->particleData.life=model->particleData.life-dt;
                    
                }else{
                    
                    //particle is dead
                    model->particleData.alive=false;
                    
                    emittedNumberOfParticles--;
                    
                    //remove the node from the scenegraph
                    removeParticleContainer.push_back(model);
                    
                }
                
            }
            
            child=child->getPrevSibling();
            
        }
        
        removeDeadParticle();
    }
    
    void U4DParticleSystem::init(){
        
        initParticleAttributes();
        loadRenderingInformation();
        
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleSystem::initParticles, timer,0.1, true);
        
    }
    
    void U4DParticleSystem::initParticles(){
        
        U4DNumerical numerical;
        U4DTrigonometry trig;
        
        U4DVector3n particleSystemPosition=getAbsolutePosition();
        
        if(getNumberOfEmittedParticles()<=getMaxNumberOfParticles()){
            
            U4DDynamicModel *particle=new U4DDynamicModel();
            
            particle->setEnableModelVisibility(false);
            particle->enableKineticsBehavior();
            particle->initMass(1.0);
            
            //set particle life
            float particleLife=particle->particleData.life;
            
            //set the position variance for the particle
            U4DVector3n positionVariance(0.5,0.5,0.5);
            
            positionVariance.x=positionVariance.x*numerical.getRandomNumberBetween(-1.0, 1.0);
            positionVariance.y=positionVariance.y*numerical.getRandomNumberBetween(-1.0, 1.0);
            positionVariance.z=positionVariance.z*numerical.getRandomNumberBetween(-1.0, 1.0);
            
            U4DVector3n position=particleSystemPosition+positionVariance;
            
            particle->translateTo(position);
            
            //set the initial velocity for the particle
            U4DVector3n emitAngle(90.0,0.0,90.0);
            U4DVector3n emitAngleVariance(0.0,0.0,0.0);
            float speed=20.0;
            
            emitAngleVariance.x=emitAngleVariance.x*numerical.getRandomNumberBetween(-1.0, 1.0);
            emitAngleVariance.y=emitAngleVariance.y*numerical.getRandomNumberBetween(-1.0, 1.0);
            emitAngleVariance.z=emitAngleVariance.z*numerical.getRandomNumberBetween(-1.0, 1.0);
            
            emitAngle=emitAngle+emitAngleVariance;
            
            U4DVector3n emitAxis(cos(trig.degreesToRad(emitAngle.x)),cos(trig.degreesToRad(emitAngle.y)),cos(trig.degreesToRad(emitAngle.z)));
            
            emitAxis.normalize();
            
            U4DVector3n emitVelocity=emitAxis*speed;
            
            particle->setVelocity(emitVelocity);
            
            //set start color and end color
            U4DVector3n startColor(1.0,0.0,0.0);
            U4DVector3n startColorVariance(0.0,0.0,0.0);
            
            startColorVariance.x=startColorVariance.x*numerical.getRandomNumberBetween(-1.0, 1.0);
            startColorVariance.y=startColorVariance.y*numerical.getRandomNumberBetween(-1.0, 1.0);
            startColorVariance.z=startColorVariance.z*numerical.getRandomNumberBetween(-1.0, 1.0);
            
            startColor=startColor+startColorVariance;
            
            U4DVector3n endColor(0.0,0.0,1.0);
            U4DVector3n endColorVariance(0.0,0.0,0.0);
            
            endColorVariance.x=endColorVariance.x*numerical.getRandomNumberBetween(-1.0, 1.0);
            endColorVariance.y=endColorVariance.y*numerical.getRandomNumberBetween(-1.0, 1.0);
            endColorVariance.z=endColorVariance.z*numerical.getRandomNumberBetween(-1.0, 1.0);
            
            endColor=endColor+endColorVariance;
            
            U4DVector3n deltaColor;
            
            deltaColor.x=(endColor.x-startColor.x)/particleLife;
            deltaColor.y=(endColor.y-startColor.y)/particleLife;
            deltaColor.z=(endColor.z-startColor.z)/particleLife;
            
            //load the info of the particle into the vector
            PARTICLEDATA particleData;
            
            //load the data into the container
            particleData.absoluteSpace=particle->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
            particleData.startColor=startColor;
            particleData.endColor=endColor;
            particleData.deltaColor=deltaColor;
            
            particleContainer.push_back(particleData);
          
            //add information to the particle node
            particle->particleData.startColor=startColor;
            particle->particleData.endColor=endColor;
            particle->particleData.deltaColor=deltaColor;
            particle->particleData.color=startColor;
            
            //add child to scenegraph
            addChild(particle);
            
            emittedNumberOfParticles++;
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
    
    void U4DParticleSystem::setNumberOfEmittedParticles(int uNumberOfEmittedParticles){
        
        emittedNumberOfParticles=uNumberOfEmittedParticles;
        
    }
    
    int U4DParticleSystem::getNumberOfEmittedParticles(){
        
        return emittedNumberOfParticles;
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
    
    std::vector<PARTICLEDATA> U4DParticleSystem::getParticleContainer(){
        
        return particleContainer;
        
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
    
}
