//
//  U4DAvoidance.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/8/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DAvoidance.h"
#include "U4DDynamicModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingSphere.h"
#include "U4DSphere.h"
#include "U4DAABB.h"
#include "U4DPlane.h"
#include "U4DRay.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    U4DAvoidance::U4DAvoidance(){
        
    }
    
    U4DAvoidance::~U4DAvoidance(){
        
    }
    
    U4DVector3n U4DAvoidance::getSteering(U4DDynamicModel *uDynamicModel){
        
        bool intersectionWithPlaneOccurred=false;
        
        U4DVector3n viewDir=uDynamicModel->getViewInDirection();
        
        viewDir.normalize();
        
        U4DVector3n velocity=uDynamicModel->getVelocity();
        
        //This is a special condition: if the character's velocity is equal to zero, and is close to the path at the start, the entity will not move. To make it move, set the velocity to the current view direction
        if (velocity.magnitudeSquare()==0) {
            velocity=viewDir;
        }
        
        U4DVector3n predictedPosition;
        
        U4DPoint3n position=uDynamicModel->getAbsolutePosition().toPoint();
        
        //ray to intersect generated plane between sphere vs. sphere or sphere vs. aabb
        U4DRay ray(position,velocity);
        
        U4DPoint3n intersectionPoint;
        float intersectionTime=0.0;
        
        //get sphere bounding the entity
        U4DBoundingVolume *boundingSphere=uDynamicModel->getBroadPhaseBoundingVolume();
        U4DSphere sphere=boundingSphere->getSphere();
        
        //intersection plane
        U4DPlane plane;
        
        //get most broad phase collision list
        for(auto n:uDynamicModel->getBroadPhaseCollisionList()){
            
            intersectionWithPlaneOccurred=false;
            
            //get bounding volume from the collision list
            U4DBoundingVolume *boundingVolume=n->getBroadPhaseBoundingVolume();
            
            //check if the entity was initialized as a platform, i.e. using aabb boundary volume
            if (n->getIsPlatform()) {
                
                U4DPoint3n minPoint=boundingVolume->getMinBoundaryPoint();
                U4DPoint3n maxPoint=boundingVolume->getMaxBoundaryPoint();
                
                U4DEngine::U4DAABB aabb(minPoint,maxPoint);
                
                U4DEngine::U4DPoint3n spherePlaneIntersectionPoint;
                
                //determine if the aabb and the sphere intersect and if so, what is the intersection point
                if(aabb.intersectionWithVolume(sphere,spherePlaneIntersectionPoint)){
                    
                    //get the plane the intersection point lies in the aabb
                    if(aabb.aabbPlanePointLies(spherePlaneIntersectionPoint,plane)){
                        
                        intersectionWithPlaneOccurred=true;
                        
                    }
                    
                }
                
            }else{
                
                U4DSphere sphere2=boundingVolume->getSphere();
                
                //get plane created by the two spheres intersection
                if(sphere2.intersectionWithVolume(sphere,plane)){
                    
                    intersectionWithPlaneOccurred=true;
                    
                }
                
            }
            
            if(intersectionWithPlaneOccurred){
                
                //intersect plane with ray going in direction of entity velocity
                ray.intersectPlane(plane, intersectionPoint, intersectionTime);
                
                predictedPosition=intersectionPoint.toVector()+plane.n*2.0;
                
                return U4DSeek::getSteering(uDynamicModel, predictedPosition);
            }
            
        }
        
        return U4DVector3n(0.0,0.0,0.0);
        
    }
    
}
