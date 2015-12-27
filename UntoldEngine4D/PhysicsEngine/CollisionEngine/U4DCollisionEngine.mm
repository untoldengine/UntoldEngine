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

    void U4DCollisionEngine::addToCollisionContainer(U4DDynamicModel* uModel){
        
        modelCollection.push_back(uModel);
        
    }

    void U4DCollisionEngine::detectCollisions(float dt){
        
        if (modelCollection.size()>1) {
            
            if(collisionAlgorithm->collision(modelCollection.at(0),modelCollection.at(1),dt)){
                
                std::cout<<"Collision Occurred"<<std::endl;
                
                
                //if collision occurred then
                modelCollection.at(0)->setModelHasCollided(true);
                modelCollection.at(1)->setModelHasCollided(true);
                
                //
                
                //Manifold Generation Algorithm
                //manifoldGenerationAlgorithm->determineCollisionManifold(modelCollection.at(0), modelCollection.at(1), collisionAlgorithm->getCurrentSimpleStruct(), collisionAlgorithm->getClosestPointToOrigin());
            
                
                //contact resolution
                contactResolution(modelCollection.at(0), dt);
                contactResolution(modelCollection.at(1), dt);
                
                
            }else{
               
                std::cout<<"Non-Collision Occurred"<<std::endl;
                modelCollection.at(0)->setModelHasCollided(false);
                modelCollection.at(1)->setModelHasCollided(false);
                
            }
        
        }

        //NEED TO REMOVE THIS
        modelCollection.clear();
    }
    
    
    void U4DCollisionEngine::contactResolution(U4DDynamicModel* uModel, float dt){
        
        U4DVector3n velocityBody(0,0,0);
        U4DVector3n angularVelocityBody(0,0,0);
        
        //Clear all forces
        uModel->clearForce();
        uModel->clearMoment();
        
        //get the contact point and line of action
        
        U4DVector3n contactPoint=uModel->getCollisionContactPoint();
        U4DVector3n lineOfAction=uModel->getCollisionNormalDirection();
        
        contactPoint=lineOfAction*contactPoint.dot(lineOfAction);
        
        //get the velocity model
        /*
         r=contact point
         vp=v+(wxr)
         */
        
        U4DVector3n Vp=uModel->getVelocity()+(uModel->getAngularVelocity().cross(contactPoint));
        
        float inverseMass=1.0/uModel->getMass();
        
        /*
         
         See page 115 in Physics for game developers
         
         |J|=-(Vr*n)(e+1)/[1/m +n*((rxn)/I)xr]
         
         */
        
        
        float j=-1*(Vp.dot(lineOfAction))*(uModel->getCoefficientOfRestitution()+1)/(inverseMass+lineOfAction.dot(uModel->getInverseMomentOfInertiaTensor()*(contactPoint.cross(lineOfAction)).cross(contactPoint)));
        
        
        /*
         
         V1after=V1before+(|J|n)/m
         
         */
        
        
        velocityBody+=uModel->getVelocity()+(lineOfAction*j)/uModel->getMass();
        
        
        
        /*
         
         w1after=w1before+(rx|j|n)/I
         */
        
        
        angularVelocityBody+=uModel->getAngularVelocity()+uModel->getInverseMomentOfInertiaTensor()*(contactPoint.cross(lineOfAction*j));
        
        uModel->setVelocity(velocityBody);
        
        uModel->setAngularVelocity(angularVelocityBody);
        
        
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
            
            repheadDown(uVolumeVertices,uVolumeVerticesIndex,index,numValues-1);
        }
        
        //sort the array
        for (index=numValues-1; index>=1; index--) {
            
            swap(uVolumeVertices,0,index);
            repheadDown(uVolumeVertices,uVolumeVerticesIndex,0,index-1);
        }
        
    }

    void U4DCollisionEngine::repheadDown(vector<U4DVector3n> &uVolumeVertices,int uVolumeVerticesIndex,int root, int bottom){
        
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
                repheadDown(uVolumeVertices,uVolumeVerticesIndex,maxChild,bottom);
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
