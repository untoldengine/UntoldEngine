//
//  U4DSphere.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#include "U4DSphere.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    U4DSphere::U4DSphere():radius(0.0),center(0.0,0.0,0.0){
            
    }
    
    U4DSphere::U4DSphere(U4DPoint3n &uCenter, float uRadius){
        
        radius=uRadius;
        center=uCenter;
        
    }
    
    U4DSphere::~U4DSphere(){
        
    }
    
    void U4DSphere::setCenter(U4DPoint3n &uCenter){
        
        center=uCenter;
    
    }
    
    void U4DSphere::setRadius(float uRadius){
        
        radius=uRadius;
        
    }
    
    U4DPoint3n U4DSphere::getCenter(){
        
        return center;
        
    }
    
    float U4DSphere::getRadius(){
        
        return radius;
        
    }
    
    bool U4DSphere::intersectionWithVolume(U4DSphere &uSphere){
        
        //Calculate squared distance between centers
        U4DVector3n distanceBetweenCentersVector=center-uSphere.center;
        float distance=distanceBetweenCentersVector.dot(distanceBetweenCentersVector);
        
        //Sphere intersect if squared distance is less than squared sum of radii
        float radiusSum=radius+uSphere.radius;
        
        return distance<=radiusSum*radiusSum;
        
    }
    
}
