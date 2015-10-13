//
//  U4DBoundingConvex.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#include "U4DBoundingConvex.h"


namespace U4DEngine {
    
    void U4DBoundingConvex::determineConvexHullOfModel(std::vector<U4DVector3n>& uVertices){
        
        float width=1.0;
        float height=1.0;
        float depth=1.0;
        
        U4DVector3n v0(width,height,depth);
        
        U4DVector3n v1(width,height,-depth);
        
        U4DVector3n v2(width,-height,depth);
        
        U4DVector3n v3(width,-height,-depth);
        
        
        
        U4DVector3n v4(-width,-height,depth);
        U4DVector3n v5(-width,-height,-depth);
        
        U4DVector3n v6(-width,height,-depth);
        U4DVector3n v7(-width,height,depth);
        
        
        bodyCoordinates.addVerticesDataToContainer(v0);
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        
        bodyCoordinates.addVerticesDataToContainer(v4);
        bodyCoordinates.addVerticesDataToContainer(v5);
        bodyCoordinates.addVerticesDataToContainer(v6);
        bodyCoordinates.addVerticesDataToContainer(v7);
 
        setGeometry();
        
    }

    


}