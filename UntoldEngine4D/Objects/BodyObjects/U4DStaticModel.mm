//
//  U4DStaticModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DStaticModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingConvex.h"
#include "U4DBoundingSphere.h"
#include "U4DBoundingAABB.h"
#include "U4DConvexHullAlgorithm.h"
#include "U4DLogger.h"
#include <algorithm>

namespace U4DEngine {
    
    U4DStaticModel::U4DStaticModel():collisionEnabled(false),narrowPhaseBoundingVolumeVisibility(false),broadPhaseBoundingVolumeVisibility(false),coefficientOfRestitution(1.0),isPlatform(false),cullingPhaseBoundingVolumeVisibility(false){
        
        initMass(1.0);
        
        U4DVector3n centerOfMass(0.0,0.0,0.0);
        
        initCenterOfMass(centerOfMass);
        
        initInertiaTensorType(cubicInertia);
        
        massProperties.intertiaTensorComputed=false;
        
        //set the convex hull bounding volume to null
        convexHullBoundingVolume=nullptr;
        
        //set the broad phase bounding volume to null
        broadPhaseBoundingVolume=nullptr;
        
        //set all collision information to zero
        clearCollisionInformation();
        
    }
    
    U4DStaticModel::~U4DStaticModel(){
    
    }
    
    U4DStaticModel::U4DStaticModel(const U4DStaticModel& value){
    
    }
    
    U4DStaticModel& U4DStaticModel::operator=(const U4DStaticModel& value){
        
        return *this;
    
    }
    
    
    #pragma mark-mass
    //set mass of object
    void U4DStaticModel::initMass(float uMass){
        
        
        massProperties.mass=uMass;
        
        
    }

    float U4DStaticModel::getMass()const{
        
        return massProperties.mass;
    }


    void U4DStaticModel::initCenterOfMass(U4DVector3n& uCenterOfMass){
        
        massProperties.centerOfMass=uCenterOfMass;
        
    }

    U4DVector3n U4DStaticModel::getCenterOfMass(){
        
    
        return massProperties.centerOfMass;
        
    }


    #pragma mark-coefficient of Restitution
    //coefficient of restitution
    void U4DStaticModel::initCoefficientOfRestitution(float uValue){

         if (uValue>1.0) {
             coefficientOfRestitution=1.0;  //coefficient can't be greater than 1
         }else if(uValue<0.0){
             coefficientOfRestitution=0.0;  //coefficient can't be less than 0
         }else{
             coefficientOfRestitution=uValue;
         }

    }

    float U4DStaticModel::getCoefficientOfRestitution(){

        return coefficientOfRestitution;
    }
    
    void U4DStaticModel::initInertiaTensorType(INERTIATENSORTYPE uInertiaTensorType){
        
        massProperties.inertiaTensorType=uInertiaTensorType;
    }
    
    INERTIATENSORTYPE U4DStaticModel::getInertiaTensorType(){
        
        return massProperties.inertiaTensorType;
    }

    #pragma mark-inertia tensor
    //set and get the intertia tensor

    void U4DStaticModel::computeInertiaTensor(){
        
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
            float uX=bodyCoordinates.getModelDimension().x;
            float uY=bodyCoordinates.getModelDimension().y;
            float uZ=bodyCoordinates.getModelDimension().z;
            
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


    U4DMatrix3n U4DStaticModel::getMomentOfInertiaTensor(){

    return massProperties.momentOfInertiaTensor;
     
    }

    U4DMatrix3n U4DStaticModel::getInverseMomentOfInertiaTensor(){

    return massProperties.inverseMomentOfInertiaTensor;

    }

   
    void U4DStaticModel::updateConvexHullVertices(){
        
        //update the position of the convex hull vertices
        
        //The position of the convex hull vertices are relative to the center of mass
        
        for(auto convexHullVertices:getNarrowPhaseBoundingVolume()->getConvexHullVertices()){
            
            convexHullVertices=getAbsoluteMatrixOrientation()*convexHullVertices;
            convexHullVertices=convexHullVertices+getAbsolutePosition();
            
            convexHullProperties.convexHullVertices.push_back(convexHullVertices);
            
        }
        
    }
    
    
    std::vector<U4DVector3n>& U4DStaticModel::getConvexHullVertices(){
        
        updateConvexHullVertices();
        
        return convexHullProperties.convexHullVertices;
        
    }
    
    int U4DStaticModel::getConvexHullVerticesCount(){
        
        return convexHullProperties.convexHullVertices.size();
        
    }
    
    void U4DStaticModel::clearConvexHullVertices(){
        
        convexHullProperties.convexHullVertices.clear();
    
    }
    
    void U4DStaticModel::enableCollisionBehavior(){
        
        //test if the bounding volume object was previously created
        if(convexHullBoundingVolume==nullptr && broadPhaseBoundingVolume==nullptr){
            
            //compute the inertia tensor
            computeInertiaTensor();
            
            //create the bounding convex volume
            convexHullBoundingVolume=new U4DBoundingConvex();
            
            //generate the convex hull for the model
            U4DConvexHullAlgorithm convexHullAlgorithm;
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("In Process: Computing Convex Hull for Collision Detection for model: %s",getName().c_str());
            
            //determine the convex hull of the model
            CONVEXHULL convexHull=convexHullAlgorithm.computeConvexHull(this->bodyCoordinates.preConvexHullVerticesContainer);
            
            //if convex hull valid, then set it to the model and enable collision
            
            if (convexHull.isValid) {
                
                logger->log("Success: Convex Hull was properly computed. Collision Detection is enabled for model: %s.",getName().c_str());
                
                //set the convex hull for the bounding volume. Note the convex hull is maintained by the U4DBoundingConvex class
                convexHullBoundingVolume->setConvexHullVertices(convexHull);
                
                //decompose the convex hull into vertices. Note this data is also contained in the bounding volume.
                for(auto n:convexHull.vertex){
                    
                    U4DVector3n vertex=n.vertex;
                    
                    bodyCoordinates.addConvexHullVerticesToContainer(vertex);
                    
                }
                
                //decompose the convex hull into segments
                for(auto n:convexHull.edges){
                    U4DSegment segment=n.segment;
                    bodyCoordinates.addConvexHullEdgesDataToContainer(segment);
                }
                
                
                //decompose the convex hull into faces
                for(auto n:convexHull.faces){
                    U4DTriangle face=n.triangle;
                    
                    bodyCoordinates.addConvexHullFacesDataToContainer(face);
                    
                }
                
                //Get body dimensions
                float xDimension=bodyCoordinates.getModelDimension().x;
                float yDimension=bodyCoordinates.getModelDimension().y;
                float zDimension=bodyCoordinates.getModelDimension().z;
                
                //set model longest dimension
                float longestModelDimension=std::max(xDimension, yDimension);
                longestModelDimension=std::max(longestModelDimension, zDimension);
                
                //get min and max points to create the AABB
                U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
                U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
                
                if (getIsPlatform()) {
                    
                    //create a AABB bounding volume
                    broadPhaseBoundingVolume=new U4DBoundingAABB();
                    
                    //calculate the AABB
                    broadPhaseBoundingVolume->computeBoundingVolume(minPoints, maxPoints);
                    
                }else{
                    
                    //create sphere bounding volume
                    broadPhaseBoundingVolume=new U4DBoundingSphere();
                    
                    //set the radius for the sphere bounding volume
                    float radius=maxPoints.distanceBetweenPoints(minPoints)/2.0;
                    
                    //calculate the sphere
                    broadPhaseBoundingVolume->computeBoundingVolume(radius, 10, 10);
                }
                
                //enable collision
                collisionEnabled=true;
                
            }else{
                logger->log("Error: Computed Convex Hull for model %s is not valid",getName().c_str());
                logger->log("Please visit www.untoldengine.com for a review on Model Topology to produce a valid Convex Hull");
                
            }
        
        }else if(convexHullBoundingVolume!=nullptr && broadPhaseBoundingVolume!=nullptr){
            
            collisionEnabled=true;
            
        }
        
        
    }
    
    void U4DStaticModel::pauseCollisionBehavior(){
        
        collisionEnabled=false;
    }
    
    
    void U4DStaticModel::resumeCollisionBehavior(){
        
        collisionEnabled=true;
    }
    
    
    bool U4DStaticModel::isCollisionBehaviorEnabled(){
        
        return collisionEnabled;
    
    }

    void U4DStaticModel::setNarrowPhaseBoundingVolumeVisibility(bool uValue){
        
        narrowPhaseBoundingVolumeVisibility=uValue;
        
    }
    
    bool U4DStaticModel::getNarrowPhaseBoundingVolumeVisibility(){
        
        return narrowPhaseBoundingVolumeVisibility;
    }
    
    void U4DStaticModel::updateNarrowPhaseBoundingVolumeSpace(){
        
        //update the bounding volume with the model current space dual quaternion (rotation and translation)
        convexHullBoundingVolume->setLocalSpace(absoluteSpace);
        
    }
    
    U4DBoundingVolume* U4DStaticModel::getNarrowPhaseBoundingVolume(){
        
        //update the narrow bounding volume space
        updateNarrowPhaseBoundingVolumeSpace();
        
        return convexHullBoundingVolume;
    }
    
    
    //Broad Phase Bounding Volume
    
    U4DBoundingVolume* U4DStaticModel::getBroadPhaseBoundingVolume(){
        
        //update the broad phase bounding volume space
        updateBroadPhaseBoundingVolumeSpace();
        
        return broadPhaseBoundingVolume;
        
    }
    
    void U4DStaticModel::setBroadPhaseBoundingVolumeVisibility(bool uValue){
        
        broadPhaseBoundingVolumeVisibility=uValue;
        
    }
    
    bool U4DStaticModel::getBroadPhaseBoundingVolumeVisibility(){
        
        return broadPhaseBoundingVolumeVisibility;
    }
    
    void U4DStaticModel::updateBroadPhaseBoundingVolumeSpace(){
        
        //update the bounding volume with the model current space dual quaternion (rotation and translation)
        broadPhaseBoundingVolume->setLocalSpace(absoluteSpace);
        
    }
    
    
    
    void U4DStaticModel::addCollisionContactPoint(U4DVector3n& uContactPoint){
        
        collisionProperties.contactManifoldProperties.contactPoint.push_back(uContactPoint);
        
    }
    
    
    void U4DStaticModel::setCollisionNormalFaceDirection(U4DVector3n& uNormalFaceDirection){
        
        collisionProperties.contactManifoldProperties.normalFaceDirection=uNormalFaceDirection;
    }
    
    void U4DStaticModel::setCollisionPenetrationDepth(float uPenetrationDepth){
        
        collisionProperties.contactManifoldProperties.penetrationDepth=uPenetrationDepth;
        
    }
    
    void U4DStaticModel::clearCollisionInformation(){
        
        clearCollisionContactPoints();
        collisionProperties.contactManifoldProperties.normalFaceDirection.zero();
        collisionProperties.contactManifoldProperties.penetrationDepth=0.0;
        
    }
    
    void U4DStaticModel::clearCollisionContactPoints(){
        collisionProperties.contactManifoldProperties.contactPoint.clear();
    }
    
    std::vector<U4DVector3n> U4DStaticModel::getCollisionContactPoints(){
        
        return collisionProperties.contactManifoldProperties.contactPoint;
        
    }
    
    U4DVector3n U4DStaticModel::getCollisionNormalFaceDirection(){
        
        return collisionProperties.contactManifoldProperties.normalFaceDirection;
        
    }
    
    float U4DStaticModel::getCollisionPenetrationDepth(){
        
        return collisionProperties.contactManifoldProperties.penetrationDepth;
        
    }
    
    void U4DStaticModel::setModelHasCollided(bool uValue){
        collisionProperties.collided=uValue;
    }
    
    bool U4DStaticModel::getModelHasCollided(){
        return collisionProperties.collided;
    }
    
    void U4DStaticModel::setNormalForce(U4DVector3n& uNormalForce){
        
        collisionProperties.contactManifoldProperties.normalForce=uNormalForce;
    }
    
    U4DVector3n U4DStaticModel::getNormalForce(){
        return collisionProperties.contactManifoldProperties.normalForce;
    }
    
    void U4DStaticModel::initAsPlatform(bool uValue){
        isPlatform=uValue;
    }
    
    bool U4DStaticModel::getIsPlatform(){
        return isPlatform;
    }
    
    void U4DStaticModel::setCollisionFilterCategory(int uFilterCategory){
        
        collisionFilter.category=uFilterCategory;
    }
    

    void U4DStaticModel::setCollisionFilterMask(int uFilterMask){
        
        collisionFilter.mask=uFilterMask;
    }
    
    void U4DStaticModel::setCollisionFilterGroupIndex(signed int uGroupIndex){
        
        collisionFilter.groupIndex=uGroupIndex;
    }
    
    int U4DStaticModel::getCollisionFilterCategory(){
        
        return collisionFilter.category;
    }
    
    int U4DStaticModel::getCollisionFilterMask(){
        
        return collisionFilter.mask;
    }

    signed int U4DStaticModel::getCollisionFilterGroupIndex(){
     
        return collisionFilter.groupIndex;
    }
    
    U4DVector3n U4DStaticModel::getModelDimensions(){
        
        return bodyCoordinates.getModelDimension();
    }
    
    void U4DStaticModel::initCullingBoundingVolume(){
        
        //Get body dimensions
        float xDimension=bodyCoordinates.getModelDimension().x;
        float yDimension=bodyCoordinates.getModelDimension().y;
        float zDimension=bodyCoordinates.getModelDimension().z;
        
        //get min and max points to create the AABB
        U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
        U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
        
        //create a AABB culling bounding volume
        cullingPhaseBoundingVolume=new U4DBoundingAABB();
        
        //calculate the culling AABB
        cullingPhaseBoundingVolume->computeBoundingVolume(minPoints, maxPoints);
        
    }
    
    void U4DStaticModel::updateCullingPhaseBoundingVolumeSpace(){
        
        //update the bounding volume with the model current space dual quaternion (rotation and translation)
        cullingPhaseBoundingVolume->setLocalSpace(absoluteSpace);
    }
    
    U4DBoundingVolume* U4DStaticModel::getCullingPhaseBoundingVolume(){
        
        //update the broad phase bounding volume space
        updateCullingPhaseBoundingVolumeSpace();
        
        return cullingPhaseBoundingVolume;
        
    }
    
    void U4DStaticModel::setCullingPhaseBoundingVolumeVisibility(bool uValue){
        
        cullingPhaseBoundingVolumeVisibility=true;
    }
    
    bool U4DStaticModel::getCullingPhaseBoundingVolumeVisibility(){
        
        return cullingPhaseBoundingVolumeVisibility;
        
    }
    
}
