//
//  U4DCollisionEngine.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DCollisionEngine.h"
#include "Constants.h"
#include "CommonProtocols.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DGJKAlgorithm.h"
#include "U4DEPAAlgorithm.h"
#include "U4DDynamicModel.h"
#include "U4DBVHManager.h"

namespace U4DEngine {
    
    U4DCollisionEngine::U4DCollisionEngine(){};

    U4DCollisionEngine::~U4DCollisionEngine(){};
    
    void U4DCollisionEngine::update(float dt){
        
    }

    void U4DCollisionEngine::setCollisionAlgorithm(U4DCollisionAlgorithm* uCollisionAlgorithm){
        
        collisionAlgorithm=uCollisionAlgorithm;
        
    }
    
    void U4DCollisionEngine::setManifoldGenerationAlgorithm(U4DManifoldGeneration* uManifoldGenerationAlgorithm){
        
        manifoldGenerationAlgorithm=uManifoldGenerationAlgorithm;
        
    }
    
    void U4DCollisionEngine::setBoundaryVolumeHierarchyManager(U4DBVHManager* uBoundaryVolumeHierarchyManager){
        
        boundaryVolumeHierarchyManager=uBoundaryVolumeHierarchyManager;
        
    }

    void U4DCollisionEngine::addToBroadPhaseCollisionContainer(U4DDynamicModel* uModel){
        
        boundaryVolumeHierarchyManager->addModelToTreeContainer(uModel);
        
    }
    
    void U4DCollisionEngine::detectBroadPhaseCollisions(float dt){
        
        //build bvh tree
        boundaryVolumeHierarchyManager->buildBVH();
        
        //determine collisions
        boundaryVolumeHierarchyManager->startCollision();
        
        //retrieve collision pairs
        collisionPairs=boundaryVolumeHierarchyManager->getBroadPhaseCollisionPairs();
        
    }

    void U4DCollisionEngine::detectNarrowPhaseCollision(float dt){
        
        
        for (auto n:collisionPairs) {
            
            U4DDynamicModel *model1=n.model1;
            U4DDynamicModel *model2 =n.model2;
            
            if (collisionAlgorithm->collision(model1, model2, dt)) {
                
                //if collision occurred then
                model1->setModelHasCollided(true);
                model2->setModelHasCollided(true);
                
                //Manifold Generation Algorithm
                U4DPoint3n closestPoints=collisionAlgorithm->getClosestCollisionPoint();
                
                if(manifoldGenerationAlgorithm->determineContactManifold(model1, model2, collisionAlgorithm->getCurrentSimpleStruct(),closestPoints)){
                    
                    //contact resolution
                    contactResolution(model1, model2, dt*model1->getTimeOfImpact());
                    //contactResolution(model2, dt*model2->getTimeOfImpact());
                    
                }else{
                    
                    std::cout<<"Contact Manifold were not found"<<std::endl;
                
                }
                
            }
                
        }
       
    }
    
    
    void U4DCollisionEngine::contactResolution(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2, float dt){
        
        U4DVector3n linearImpulseFactorOfModel1(0,0,0);
        U4DVector3n angularImpulseFactorOfModel1(0,0,0);
 
        U4DVector3n linearImpulseFactorOfModel2(0,0,0);
        U4DVector3n angularImpulseFactorOfModel2(0,0,0);
        
        //Clear all forces
        uModel1->clearForce();
        uModel1->clearMoment();
        
        uModel2->clearForce();
        uModel2->clearMoment();
        
        //set timestep for model
        //dt=dt*uModel->getTimeOfImpact();
        
        //get the contact point and line of action
        
        std::vector<U4DVector3n> contactManifold=uModel1->getCollisionContactPoints();
        
        U4DVector3n normalCollisionVector=uModel1->getCollisionNormalFaceDirection();
        
        U4DVector3n centerOfMassForModel1=uModel1->getCenterOfMass()+uModel1->getAbsolutePosition();
        U4DVector3n centerOfMassForModel2=uModel2->getCenterOfMass()+uModel2->getAbsolutePosition();
        
        float inverseMassOfModel1=1.0/uModel1->getMass();
        float inverseMassOfModel2=1.0/uModel2->getMass();
        float totalInverseMasses=inverseMassOfModel1+inverseMassOfModel2;
        
        for(auto n:contactManifold){
            
            U4DVector3n radiusOfModel1=n-centerOfMassForModel1;
            U4DVector3n radiusOfModel2=n-centerOfMassForModel2;
            
            //get the velocity model
            /*
             r=contact point
             vp=v+(wxr)
             */
            
            U4DVector3n vpModel1=uModel1->getVelocity()+(uModel1->getAngularVelocity().cross(radiusOfModel1));
            U4DVector3n vpModel2=uModel2->getVelocity()+(uModel2->getAngularVelocity().cross(radiusOfModel2));
            
            U4DVector3n vR=vpModel2-vpModel1;
            

            /*
             
             See page 115 in Physics for game developers
             
             |J|=-(Vr*n)(e+1)/[1/m +n*((rxn)/I)xr]
             
             */
            
            U4DVector3n angularFactorOfModel1=uModel1->getInverseMomentOfInertiaTensor()*(radiusOfModel1.cross(normalCollisionVector)).cross(radiusOfModel1);
            
            U4DVector3n angularFactorOfModel2=uModel2->getInverseMomentOfInertiaTensor()*(radiusOfModel2.cross(normalCollisionVector)).cross(radiusOfModel2);
            
            float totalAngularEffect=normalCollisionVector.dot(angularFactorOfModel1+angularFactorOfModel2);
            
            float j=MAX(-1*(vR.dot(normalCollisionVector))*(1.0+1.0)/(totalInverseMasses+totalAngularEffect),0.5);
            
            /*
             
             Linear Impulse factor=(|J|n)/m
             
             */
            
            linearImpulseFactorOfModel1+=(normalCollisionVector*j)*inverseMassOfModel1;
            linearImpulseFactorOfModel2+=(normalCollisionVector*j)*inverseMassOfModel2;
            
            /*
             
             Angular Impulse factor=(rx|j|n)/I
             */
            
            
            angularImpulseFactorOfModel1+=uModel1->getInverseMomentOfInertiaTensor()*(radiusOfModel1.cross(normalCollisionVector*j));
            
            angularImpulseFactorOfModel2+=uModel2->getInverseMomentOfInertiaTensor()*(radiusOfModel2.cross(normalCollisionVector*j));
            
        }
        
        angularImpulseFactorOfModel1.show("angular");
        //Add the new velocity to the previous velocity
        /*
         
         V1after=V1before+(|J|n)/m
         
         */
        U4DVector3n newLinearVelocityOfModel1=uModel1->getVelocity()-linearImpulseFactorOfModel1;
        U4DVector3n newLinearVelocityOfModel2=uModel2->getVelocity()+linearImpulseFactorOfModel2;

        //Add the new angular velocity to the previous velocity
        /*
         
         w1after=w1before+(rx|j|n)/I
         */
        
        U4DVector3n newAngularVelocityOfModel1=uModel1->getAngularVelocity()-angularImpulseFactorOfModel1;
        U4DVector3n newAngularVelocityOfModel2=uModel2->getAngularVelocity()+angularImpulseFactorOfModel2;
        
        //Set the new linear and angular velocities for the models
        uModel1->setVelocity(newLinearVelocityOfModel1);
        
        uModel1->setAngularVelocity(newAngularVelocityOfModel1);
        
//        uModel2->setVelocity(newLinearVelocityOfModel2);
//    
//        uModel2->setAngularVelocity(newAngularVelocityOfModel2);
        
        //determine if the motion of the body is too low and set body to sleep
//        float currentMotion1=newLinearVelocityOfModel1.magnitudeSquare()+newAngularVelocityOfModel1.magnitudeSquare();
//        float currentMotion2=newLinearVelocityOfModel2.magnitudeSquare()+newAngularVelocityOfModel2.magnitudeSquare();
//        
//        uModel1->setMotion(currentMotion1,dt);
//        uModel2->setMotion(currentMotion2,dt);
        
    }
    
    
    void U4DCollisionEngine::clearContainers(){
        
        boundaryVolumeHierarchyManager->clearContainers();
        collisionPairs.clear();
    }
    
    /*
    void U4DCollisionEngine::collisionDetection(U4DDynamicModel* uModel,float dt){
        
        //create a plane
        U4DVector3n normal(0,1,0);
        float d=0.0;
        
        U4DPlane plane(normal,d);
        
        //did collision occurred with a plane
        if(collision(uModel,plane)==true)
        {
            //determine the contact point
            determineContactPoint(uModel,plane);
            
            //Get contact Resolution
            contactResolution(uModel,dt);
            
            //set body collided
            uModel->collisionProperties.collided=true;
            
        }else{
            uModel->collisionProperties.collided=false;
        }
        
    }

    void U4DCollisionEngine::collisionDetection(float dt){
        

        if (modelCollection.size()>=2) {
            
        if (collision(modelCollection.at(0), modelCollection.at(1))) {
            
            //detect collision of two objects
            
        }
        
        
        //clear all models
        modelCollection.clear();
        
        }
    }



    //Test if OBB intersects plane p
    bool U4DCollisionEngine::collision(U4DDynamicModel* uModel,U4DPlane& uPlane){
        
        bool collisionOccured=false;
        U4DOBB *obb=(U4DOBB*)uModel->obbBoundingVolume;
        
        collisionOccured=obb->testOBBPlane(uPlane);

        return collisionOccured;
    }

    bool U4DCollisionEngine::collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2){
        
        bool collisionOccured=false;
        
        U4DOBB *obb1=(U4DOBB*)uModel1->obbBoundingVolume;
        U4DOBB *obb2=(U4DOBB*)uModel2->obbBoundingVolume;
        
        collisionOccured=obb1->testOBBOBB(obb2);
        
        return collisionOccured;
    }


    void U4DCollisionEngine::determineContactPoint(U4DDynamicModel* uModel, U4DPlane& uPlane){
     
        //clear any contact point and forces

        uModel->collisionProperties.contactForcePoints.contactPoints.clear();
        uModel->collisionProperties.contactForcePoints.forceOnContactPoint.clear();
        
        U4DOBB *obb=(U4DOBB*)uModel->obbBoundingVolume;
       
        uModel->collisionProperties.contactForcePoints.contactPoints=obb->computeVertexIntersectingPlane(uPlane);
        
        
        //We need to get the forces acted on each contact point
        //since the model is in contact with the plane, the resultant force is its weigh in opposite direction
        
        lineOfAction=uPlane.n;
        lineOfAction.normalize();
     
    }


    void U4DCollisionEngine::contactResolution(U4DDynamicModel* uModel,float dt){
        
      
        
    }
    */




    /*
    void U4DCollisionEngine::heapSorting(vector<U4DVector3n> &uVolumeVertices,int uVolumeVerticesIndex){
        
        int index; //index of boneDataContainer element
        
        int numValues=(int)uVolumeVertices.size();
        
        //convert the array of values into a heap
        
        for (index=numValues/2-1; index>=0; index--) {
            
            reHeapDown(uVolumeVertices,uVolumeVerticesIndex,index,numValues-1);
        }
        
        //sort the array
        for (index=numValues-1; index>=1; index--) {
            
            swap(uVolumeVertices,0,index);
            reHeapDown(uVolumeVertices,uVolumeVerticesIndex,0,index-1);
        }
        
    }

    void U4DCollisionEngine::reHeapDown(vector<U4DVector3n> &uVolumeVertices,int uVolumeVerticesIndex,int root, int bottom){
        
        int maxChild;
        int rightChild;
        int leftChild;
        
        leftChild=root*2+1;
        rightChild=root*2+2;
        
        
        
        if (leftChild<=bottom) {
            
            if (leftChild==bottom) {
                
                maxChild=leftChild;
                
            }else{
                
                if ((uVolumeVertices.at(leftChild)).squareMagnitude() <= (uVolumeVertices.at(rightChild)).squareMagnitude()) {
                    
                    maxChild=rightChild;
                    
                }else{
                    maxChild=leftChild;
                }
            }
            
            if ((uVolumeVertices.at(root)).squareMagnitude()<(uVolumeVertices.at(maxChild)).squareMagnitude()) {
                
                swap(uVolumeVertices,root,maxChild);
                reHeapDown(uVolumeVertices,uVolumeVerticesIndex,maxChild,bottom);
            }
        }
        
    }



    void U4DCollisionEngine::swap(vector<U4DVector3n> &uVolumeVertices,int uIndex1, int uIndex2){
        
        U4DVector3n vertex1=uVolumeVertices.at(uIndex1);
        U4DVector3n vertex2=uVolumeVertices.at(uIndex2);
        
        uVolumeVertices.at(uIndex1)=vertex2;
        uVolumeVertices.at(uIndex2)=vertex1;
        
    }
    */

}
