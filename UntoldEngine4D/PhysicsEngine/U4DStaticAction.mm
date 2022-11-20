//
//  U4DStaticAction.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DStaticAction.h"
#include "U4DMesh.h"
#include "U4DConvexHullMesh.h"
#include "U4DSphereMesh.h"
#include "U4DAABBMesh.h"
#include "U4DResourceLoader.h"
#include "U4DLogger.h"
#include <algorithm>

namespace U4DEngine {
    
    U4DStaticAction::U4DStaticAction(U4DModel *uU4DModel):model(uU4DModel),collisionEnabled(false),coefficientOfRestitution(1.0),isPlatform(false), isCollisionSensor(false),convexHullBoundingVolume(nullptr),broadPhaseBoundingVolume(nullptr){
        
        initMass(10.0);
        
        U4DVector3n centerOfMass(0.0,0.0,0.0);
        
        initCenterOfMass(centerOfMass);
        
        initInertiaTensorType(cubicInertia);
        
        massProperties.intertiaTensorComputed=false;
        
        //set all collision information to zero
        clearCollisionInformation();
        
    }
    
    U4DStaticAction::~U4DStaticAction(){
    
        if(convexHullBoundingVolume!=nullptr){
            //remove parent from the bounding volute
            U4DEntity *parent=convexHullBoundingVolume->getParent();
            
            parent->removeChild(convexHullBoundingVolume);
            delete convexHullBoundingVolume;
            
            parent->removeChild(broadPhaseBoundingVolume);
            
            delete broadPhaseBoundingVolume;
            
            convexHullBoundingVolume=nullptr;
            broadPhaseBoundingVolume=nullptr;
        }
        
        //clear the convex hull data stored in the model buffers.
        clearModelCollisionData();
        
    }
    
    U4DStaticAction::U4DStaticAction(const U4DStaticAction& value){
    
    }
    
    U4DStaticAction& U4DStaticAction::operator=(const U4DStaticAction& value){
        
        return *this;
    
    }
    
    #pragma mark-mass
    //set mass of object
    void U4DStaticAction::initMass(float uMass){
        
        
        massProperties.mass=uMass;
        
        
    }

    float U4DStaticAction::getMass()const{
        
        return massProperties.mass;
    }


    void U4DStaticAction::initCenterOfMass(U4DVector3n& uCenterOfMass){
        
        massProperties.centerOfMass=uCenterOfMass;
        
    }

    U4DVector3n U4DStaticAction::getCenterOfMass(){
        
    
        return massProperties.centerOfMass;
        
    }


    #pragma mark-coefficient of Restitution
    //coefficient of restitution
    void U4DStaticAction::initCoefficientOfRestitution(float uValue){

         if (uValue>1.0) {
             coefficientOfRestitution=1.0;  //coefficient can't be greater than 1
         }else if(uValue<0.0){
             coefficientOfRestitution=0.0;  //coefficient can't be less than 0
         }else{
             coefficientOfRestitution=uValue;
         }

    }

    float U4DStaticAction::getCoefficientOfRestitution(){

        return coefficientOfRestitution;
    }
    
    void U4DStaticAction::initInertiaTensorType(INERTIATENSORTYPE uInertiaTensorType){
        
        massProperties.inertiaTensorType=uInertiaTensorType;
    }
    
    INERTIATENSORTYPE U4DStaticAction::getInertiaTensorType(){
        
        return massProperties.inertiaTensorType;
    }

    #pragma mark-inertia tensor
    //set and get the intertia tensor

    void U4DStaticAction::computeInertiaTensor(){
        
        //if the inertia tensor hasn't been computed for the body, then computed. I check this to avoid multiple computations of the inertia tensor. for example, when the collision or physics behaviors are enabled.
        
        if (massProperties.intertiaTensorComputed==false) {
            
            U4DMatrix3n tensor;
            
            //	0	3	6
            //	1	4	7
            //	2	5	8
            
            float Ixx=0.0;
            float Iyy=0.0;
            float Izz=0.0;
            
            float Ixy=0.0;
            float Ixz=0.0;
            float Iyz=0.0;
            
            //get inertia tensor type
            INERTIATENSORTYPE inertiaType=getInertiaTensorType();
            
            //Get body dimensions
            float uX=model->bodyCoordinates.getModelDimension().x;
            float uY=model->bodyCoordinates.getModelDimension().y;
            float uZ=model->bodyCoordinates.getModelDimension().z;
            
            if (inertiaType==sphericalInertia) {
                
                uX=uX/2.0;
                uY=uY/2.0;
                uZ=uZ/2.0;
                
                //Inertia Tensor for spherical bodies
                Ixx=(2*uX*uX)*massProperties.mass/5.0;
                Iyy=(2*uX*uX)*massProperties.mass/5.0;
                Izz=(2*uX*uX)*massProperties.mass/5.0;
                
                Ixy=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.y);
                Ixz=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.z);
                Iyz=massProperties.mass*(massProperties.centerOfMass.y*massProperties.centerOfMass.z);
                
            }else if(inertiaType==cylindricalInertia){
                //Inertia Tensor for cylindrical bodies
                
                
                uX=uX/2.0;
                
                Ixx=(3*uX*uX+uY*uY)*massProperties.mass/12.0;
                Iyy=(3*uX*uX+uY*uY)*massProperties.mass/12.0;
                Izz=(uX*uX)*massProperties.mass/2.0;
                
                Ixy=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.y);
                Ixz=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.z);
                Iyz=massProperties.mass*(massProperties.centerOfMass.y*massProperties.centerOfMass.z);
                
                
            }else{
                
                //Inertia Tensor for cubic bodies
                Ixx=(uY*uY+uZ*uZ)*massProperties.mass/12.0;
                Iyy=(uX*uX+uZ*uZ)*massProperties.mass/12.0;
                Izz=(uX*uX+uY*uY)*massProperties.mass/12.0;
        
                Ixy=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.y);
                Ixz=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.z);
                Iyz=massProperties.mass*(massProperties.centerOfMass.y*massProperties.centerOfMass.z);
            }
            

            tensor.matrixData[0]=Ixx;
            tensor.matrixData[4]=Iyy;
            tensor.matrixData[8]=Izz;
            
            tensor.matrixData[3]=-Ixy;
            tensor.matrixData[6]=-Ixz;
            tensor.matrixData[7]=Iyz;
            
            tensor.matrixData[1]=-Ixy;
            tensor.matrixData[2]=-Ixz;
            tensor.matrixData[5]=-Iyz;
            
            
            massProperties.momentOfInertiaTensor=tensor;
            massProperties.inverseMomentOfInertiaTensor=tensor.inverse();
            
            massProperties.intertiaTensorComputed=true;
        }
    }


    U4DMatrix3n U4DStaticAction::getMomentOfInertiaTensor(){

    return massProperties.momentOfInertiaTensor;
     
    }

    U4DMatrix3n U4DStaticAction::getInverseMomentOfInertiaTensor(){

    return massProperties.inverseMomentOfInertiaTensor;

    }

   
    void U4DStaticAction::updateConvexHullVertices(){
        
        //update the position of the convex hull vertices
        
        //The position of the convex hull vertices are relative to the center of mass
        
        for(auto convexHullVertices:getNarrowPhaseBoundingVolume()->getConvexHullVertices()){
            
            convexHullVertices=model->getAbsoluteMatrixOrientation()*convexHullVertices;
            convexHullVertices=convexHullVertices+model->getAbsolutePosition();
            
            convexHullProperties.convexHullVertices.push_back(convexHullVertices);
            
        }
        
    }
    
    
    std::vector<U4DVector3n>& U4DStaticAction::getConvexHullVertices(){
        
        updateConvexHullVertices();
        
        return convexHullProperties.convexHullVertices;
        
    }
    
    int U4DStaticAction::getConvexHullVerticesCount(){
        
        return convexHullProperties.convexHullVertices.size();
        
    }
    
    void U4DStaticAction::clearConvexHullVertices(){
        
        convexHullProperties.convexHullVertices.clear();
    
    }
    
    void U4DStaticAction::enableCollisionBehavior(){
        
        //test if the bounding volume object was previously created
        if(convexHullBoundingVolume==nullptr && broadPhaseBoundingVolume==nullptr){
            
            //compute the inertia tensor
            computeInertiaTensor();
            
            //create the bounding convex volume
            convexHullBoundingVolume=new U4DConvexHullMesh();
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("In Process: Computing Convex Hull for Collision Detection for model: %s",model->getName().c_str());
            
            //determine the convex hull of the model
            U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
            
            CONVEXHULL convexHull=resourceLoader->loadConvexHullForMesh(model);
            
            //if convex hull valid, then set it to the model and enable collision
            
            if (convexHull.isValid) {
                
                logger->log("Success: Convex Hull was properly computed. Collision Detection is enabled for model: %s.",model->getName().c_str());
                
                //set the convex hull for the bounding volume. Note the convex hull is maintained by the U4DConvexHullMesh class
                convexHullBoundingVolume->setConvexHullVertices(convexHull);
                
                //decompose the convex hull into vertices. Note this data is also contained in the bounding volume.
                for(const auto& n:convexHull.vertex){
                    
                    U4DVector3n vertex=n.vertex;
                    
                    model->bodyCoordinates.addConvexHullVerticesToContainer(vertex);
                    
                }
                
                //decompose the convex hull into segments
                for(const auto& n:convexHull.edges){
                    U4DSegment segment=n.segment;
                    model->bodyCoordinates.addConvexHullEdgesDataToContainer(segment);
                }
                
                
                //decompose the convex hull into faces
                for(const auto& n:convexHull.faces){
                    U4DTriangle face=n.triangle;
                    
                    model->bodyCoordinates.addConvexHullFacesDataToContainer(face);
                    
                }
                
                //Get body dimensions
                float xDimension=model->bodyCoordinates.getModelDimension().x;
                float yDimension=model->bodyCoordinates.getModelDimension().y;
                float zDimension=model->bodyCoordinates.getModelDimension().z;
                
                //set model longest dimension
                float longestModelDimension=std::max(xDimension, yDimension);
                longestModelDimension=std::max(longestModelDimension, zDimension);
                
                //get min and max points to create the AABB
                U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
                U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
                
                if (getIsPlatform()) {
                    
                    //create a AABB bounding volume
                    broadPhaseBoundingVolume=new U4DAABBMesh();
                    
                    //add padding to the AABB bounding volume
                    U4DPoint3n aabbMinPoints=minPoints*U4DEngine::aabbBoundingVolumePadding;
                    U4DPoint3n aabbMaxPoints=maxPoints*U4DEngine::aabbBoundingVolumePadding;
                    
                    //calculate the AABB
                    broadPhaseBoundingVolume->computeBoundingVolume(aabbMinPoints, aabbMaxPoints);
                    
                }else{
                    
                    //create sphere bounding volume
                    broadPhaseBoundingVolume=new U4DSphereMesh();
                    
                    //set the radius for the sphere bounding volume
                    float radius=maxPoints.distanceBetweenPoints(minPoints)*U4DEngine::sphereBoundingVolumePadding;
                    
                    //calculate the sphere
                    broadPhaseBoundingVolume->computeBoundingVolume(radius, 10, 10);
                }
                
                //add convex boundary volume as a child of the object
                model->addChild(convexHullBoundingVolume);
                
                //add broad boundary volume as a child of the object
                model->addChild(broadPhaseBoundingVolume);
                
                //enable collision
                collisionEnabled=true;
                
            }else{
                
                delete convexHullBoundingVolume;
                convexHullBoundingVolume=nullptr;
                
                logger->log("Error: Computed Convex Hull for model %s is not valid",model->getName().c_str());
                logger->log("Please visit www.untoldengine.com for a review on Model Topology to produce a valid Convex Hull");
                
            }
        
        }else if(convexHullBoundingVolume!=nullptr && broadPhaseBoundingVolume!=nullptr){
            
            collisionEnabled=true;
            
        }
        
        
    }
    
    void U4DStaticAction::pauseCollisionBehavior(){
        
        collisionEnabled=false;
    }
    
    
    void U4DStaticAction::resumeCollisionBehavior(){
        
        collisionEnabled=true;
    }
    
    
    bool U4DStaticAction::isCollisionBehaviorEnabled(){
        
        return collisionEnabled;
    
    }

    void U4DStaticAction::setNarrowPhaseBoundingVolumeVisibility(bool uValue){
        
        convexHullBoundingVolume->setVisibility(uValue);
        
    }
    
    bool U4DStaticAction::getNarrowPhaseBoundingVolumeVisibility(){
        
        return convexHullBoundingVolume->getVisibility();
    }
    
    U4DMesh* U4DStaticAction::getNarrowPhaseBoundingVolume(){
        
        return convexHullBoundingVolume;
    }
    
    
    //Broad Phase Bounding Volume
    
    U4DMesh* U4DStaticAction::getBroadPhaseBoundingVolume(){
        
        return broadPhaseBoundingVolume;
        
    }
    
    void U4DStaticAction::setBroadPhaseBoundingVolumeVisibility(bool uValue){
        
        broadPhaseBoundingVolume->setVisibility(uValue);
        
    }
    
    bool U4DStaticAction::getBroadPhaseBoundingVolumeVisibility(){
        
        return broadPhaseBoundingVolume->getVisibility();
    }
    
    
    void U4DStaticAction::addCollisionContactPoint(U4DVector3n& uContactPoint){
        
        collisionProperties.contactManifoldProperties.contactPoint.push_back(uContactPoint);
        
    }
    
    
    void U4DStaticAction::setCollisionNormalFaceDirection(U4DVector3n& uNormalFaceDirection){
        
        collisionProperties.contactManifoldProperties.normalFaceDirection=uNormalFaceDirection;
    }
    
    void U4DStaticAction::setCollisionPenetrationDepth(float uPenetrationDepth){
        
        collisionProperties.contactManifoldProperties.penetrationDepth=uPenetrationDepth;
        
    }
    
    void U4DStaticAction::clearCollisionInformation(){
        
        clearCollisionContactPoints();
        collisionProperties.contactManifoldProperties.normalFaceDirection.zero();
        collisionProperties.contactManifoldProperties.penetrationDepth=0.0;
        
    }
    
    void U4DStaticAction::clearCollisionContactPoints(){
        collisionProperties.contactManifoldProperties.contactPoint.clear();
    }
    
    std::vector<U4DVector3n> U4DStaticAction::getCollisionContactPoints(){
        
        return collisionProperties.contactManifoldProperties.contactPoint;
        
    }
    
    U4DVector3n U4DStaticAction::getCollisionNormalFaceDirection(){
        
        return collisionProperties.contactManifoldProperties.normalFaceDirection;
        
    }
    
    float U4DStaticAction::getCollisionPenetrationDepth(){
        
        return collisionProperties.contactManifoldProperties.penetrationDepth;
        
    }
    
    void U4DStaticAction::setModelHasCollided(bool uValue){
        collisionProperties.collided=uValue;
    }
    
    void U4DStaticAction::setModelHasCollidedBroadPhase(bool uValue){
        collisionProperties.broadPhaseCollided=uValue;
    }
    
    bool U4DStaticAction::getModelHasCollided(){
        return collisionProperties.collided;
    }
    
    bool U4DStaticAction::getModelHasCollidedBroadPhase(){
        return collisionProperties.broadPhaseCollided;
    }
    
    void U4DStaticAction::setNormalForce(U4DVector3n& uNormalForce){
        
        collisionProperties.contactManifoldProperties.normalForce=uNormalForce;
    }
    
    U4DVector3n U4DStaticAction::getNormalForce(){
        return collisionProperties.contactManifoldProperties.normalForce;
    }
    
    void U4DStaticAction::initAsPlatform(bool uValue){
        isPlatform=uValue;
    }
    
    bool U4DStaticAction::getIsPlatform(){
        return isPlatform;
    }
    
    void U4DStaticAction::setCollisionFilterCategory(int uFilterCategory){
        
        collisionFilter.category=uFilterCategory;
    }
    

    void U4DStaticAction::setCollisionFilterMask(int uFilterMask){
        
        collisionFilter.mask=uFilterMask;
    }
    
    void U4DStaticAction::setCollisionFilterGroupIndex(signed int uGroupIndex){
        
        collisionFilter.groupIndex=uGroupIndex;
    }
    
    int U4DStaticAction::getCollisionFilterCategory(){
        
        return collisionFilter.category;
    }
    
    int U4DStaticAction::getCollisionFilterMask(){
        
        return collisionFilter.mask;
    }

    signed int U4DStaticAction::getCollisionFilterGroupIndex(){
     
        return collisionFilter.groupIndex;
    }
    
    
    
    void U4DStaticAction::setIsCollisionSensor(bool uValue){
        
        isCollisionSensor=uValue;
    }
    
    bool U4DStaticAction::getIsCollisionSensor(){
        
        return isCollisionSensor;
    
    }
    
    void U4DStaticAction::addToCollisionList(U4DStaticAction *uModel){
        
        collisionList.push_back(uModel);
        
    }
    
    void U4DStaticAction::addToBroadPhaseCollisionList(U4DStaticAction *uModel){
        
        broadPhaseCollisionList.push_back(uModel);
        
    }
    
    std::vector<U4DStaticAction *> U4DStaticAction::getCollisionList(){
        
        return collisionList;
        
    }
    
    std::vector<U4DStaticAction *> U4DStaticAction::getBroadPhaseCollisionList(){
        
        return broadPhaseCollisionList;
        
    }
    
    void U4DStaticAction::setCollidingTag(std::string uCollidingTag){
        
        collidingTag=uCollidingTag;
    }
    
    std::string U4DStaticAction::getCollidingTag(){
        
        return collidingTag;
        
    }
    
    void U4DStaticAction::clearCollisionList(){
        
        collisionList.clear();
    }
    
    void U4DStaticAction::clearBroadPhaseCollisionList(){
        
        broadPhaseCollisionList.clear();
    
    }

    void U4DStaticAction::clearModelCollisionData(){
        
        model->bodyCoordinates.convexHullVerticesContainer.clear();
        model->bodyCoordinates.convexHullEdgesContainer.clear();
        model->bodyCoordinates.convexHullFacesContainer.clear();
//        model->bodyCoordinates.addConvexHullVerticesToContainer.clear();
//        model->bodyCoordinates.addConvexHullEdgesDataToContainer.clear();
//        model->bodyCoordinates.addConvexHullFacesDataToContainer.clear();
    }
    
    
    
}
