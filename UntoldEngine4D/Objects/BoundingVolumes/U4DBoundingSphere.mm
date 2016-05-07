//
//  U4DBoundingSphere.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DBoundingSphere.h"
#include "U4DMatrix4n.h"

namespace U4DEngine {
    
    U4DBoundingSphere::U4DBoundingSphere(){
    
    }
    
    
    U4DBoundingSphere::~U4DBoundingSphere(){
    
    }
    
    
    U4DBoundingSphere::U4DBoundingSphere(const U4DBoundingSphere& value){
        
        radius=value.radius;
        sphere=value.sphere;
        
    };
    
    
    U4DBoundingSphere& U4DBoundingSphere::operator=(const U4DBoundingSphere& value){
        
        radius=value.radius;
        sphere=value.sphere;
        return *this;
        
    };
    
    void U4DBoundingSphere::computeBoundingVolume(float uRadius,int uRings, int uSectors){

        radius=uRadius;
        
        sphere.setRadius(radius);
        
        float R=1.0/(uRings-1);
        float S=1.0/(uSectors-1);
        
        int r,s;
        
        
        for (r=0; r<uRings; r++) {
            
            for (s=0; s<uSectors; s++) {
                
                float uY=sin(-M_PI_2+M_PI*r*R);
                float uX=cos(2*M_PI * s * S) * sin( M_PI * r * R );
                float uZ=sin(2*M_PI * s * S) * sin( M_PI * r * R );
                
                uX*=uRadius;
                uY*=uRadius;
                uZ*=uRadius;
                
                U4DVector3n vec(uX,uY,uZ);
                
                bodyCoordinates.addVerticesDataToContainer(vec);
               
                //push to index
                
                int curRow=r*uSectors;
                int nextRow=(r+1)*uSectors;
                
                U4DIndex index(curRow+s,nextRow+s,nextRow+(s+1));
                bodyCoordinates.addIndexDataToContainer(index);
                
                U4DIndex index2(curRow+s,nextRow+s,curRow+(s+1));
                bodyCoordinates.addIndexDataToContainer(index2);
                
            }
        }
        
        loadRenderingInformation();
        
    }
    
    void U4DBoundingSphere::setRadius(float uRadius){
        
        radius=uRadius;
    }
    
    float U4DBoundingSphere::getRadius(){
        
        return radius;
    }
    
    U4DPoint3n U4DBoundingSphere::getMaxBoundaryPoint(){
        
        U4DPoint3n position=getAbsolutePosition().toPoint();
        
        return U4DPoint3n(position.x+radius,position.y+radius,position.z+radius);
    
    }
    
    U4DPoint3n U4DBoundingSphere::getMinBoundaryPoint(){
    
        U4DPoint3n position=getAbsolutePosition().toPoint();
        
        return U4DPoint3n(position.x-radius,position.y-radius,position.z-radius);
        
    }
    
    U4DSphere& U4DBoundingSphere::getSphere(){
        
        //update the sphere information with bounding sphere
        U4DPoint3n updateCenter=getAbsolutePosition().toPoint();
        
        sphere.setCenter(updateCenter);
        
        return sphere;
    }

}