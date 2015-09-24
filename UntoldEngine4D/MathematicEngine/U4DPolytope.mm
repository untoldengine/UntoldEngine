//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"
#include <algorithm>

namespace U4DEngine {
    
    U4DPolytope::U4DPolytope(){
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }
    
    void U4DPolytope::addFaceToPolytope(U4DTriangle& uTriangle){
        
        bool triangleExist=false;
        
        //check if triangle exist, if it does, do not add it
        if(polytopeFaces.size()==0){
            
            POLYTOPEFACES faces;
            faces.triangle=uTriangle;
            faces.isSeenByPoint=false;
            
            polytopeFaces.push_back(faces);
            
        }else{
            
            for (int i=0; i<polytopeFaces.size(); i++) {
            
                if (polytopeFaces.at(i).triangle==uTriangle) {
                    
                    triangleExist=true;
                    
                    break;
                }
            }
            
            
            if (triangleExist==false) { //if triangle does not exist, then add it
                
                POLYTOPEFACES faces;
                faces.triangle=uTriangle;
                faces.isSeenByPoint=false;
                
                polytopeFaces.push_back(faces);
                
            }
            
        }
        
       
        
    }

    U4DTriangle U4DPolytope::closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<polytopeFaces.size(); i++) {
           
            
             //get normal of triangle
            U4DVector3n normal=polytopeFaces.at(i).triangle.getTriangleNormal();
            
            //get distance from normal to point
            normal-=uPoint.toVector();
            
            float normalDistance=normal.magnitudeSquare();
            
            if (normalDistance<=distance) {
                
                distance=normalDistance;
                
                index=i;
                
            }
            
     }
        
        return polytopeFaces.at(index).triangle;
        
    }
    
    std::vector<POLYTOPEFACES>& U4DPolytope::getFacesOfPolytope(){
        
        return polytopeFaces;
    }
    
    
    void U4DPolytope::removeAllFaces(){
        polytopeFaces.clear();
    }
    
}