//
//  U4DBoundingPlane.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DBoundingPlane.h"
#include "U4DCamera.h"



void U4DBoundingPlane::initPlaneGeometry(U4DVector3n& uNormal,U4DVector3n& uPoint){
    
    normal=uNormal;
    point=uPoint;
    
    //find D
    
    float D=normal.dot(point);
    
    //equation
    //Nx*X + Ny*Y + Nz*Z - D=0
    
    //find the vertices
    
    for (float x=-10;x<10;x++) {
        
        for (float y=-10;y<10;y++) {
            
            for (float z=-10;z<10; z++) {
                
                float ans=uNormal.x*x +uNormal.y*y +uNormal.z*z-D;
                
                if (ans==0) {
                    
                    U4DVector3n vec(x,y,z);
                    
                    bodyCoordinates.addVerticesDataToContainer(vec);
                    
                }
                
                
            }
            
        }
    }
    
    setGeometry();

}
