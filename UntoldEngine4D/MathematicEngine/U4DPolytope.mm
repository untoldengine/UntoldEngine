//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"

namespace U4DEngine {
    
    U4DPolytope::U4DPolytope(){
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }
    
    void U4DPolytope::addTriangleToPolytope(U4DTriangle& uTriangle){
        
        bool triangleExist=false;
        
        //check if triangle exist, if it does, do not add it
        if(triangles.size()==0){
            
            uTriangle.tag=false;
            triangles.push_back(uTriangle);
            
        }else{
            
            for (int i=0; i<triangles.size(); i++) {
                
                if (triangles.at(i)==uTriangle) {
                    
                    triangleExist=true;
                    triangles.at(i).tag=true;
                    
                    break;
                }
            }
            
            
            if (triangleExist==false) {
                uTriangle.tag=false;
                triangles.push_back(uTriangle);
            }
            
        }
        
       
        
    }

    U4DTriangle U4DPolytope::closestTriangleOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<triangles.size(); i++) {
           
            if (triangles.at(i).tag==false) {
                
            
            //get normal of triangle
            U4DVector3n normal=triangles.at(i).getTriangleNormal();
            
            float normalDistance=normal.magnitudeSquare();
            
            if (normalDistance<distance) {
                
                distance=normalDistance;
                
                index=i;
                
            }
            
        }
     }
        
        return triangles.at(index);
        
    }
    
    std::vector<U4DTriangle>& U4DPolytope::getTrianglesOfPolytope(){
        
        return triangles;
    }
    
    
}