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
    
    U4DPolytope::U4DPolytope():index(0){
        
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
            faces.index=index;
            
            polytopeFaces.push_back(faces);
            
        }else{
            
            for (auto &currentfaces:polytopeFaces) {
            
               
                if (currentfaces.triangle==uTriangle) {
                    
                    triangleExist=true;
                    
                    break;
                }
            }
            
            
            if (triangleExist==false) { //if triangle does not exist, then add it
                
                POLYTOPEFACES faces;
                faces.triangle=uTriangle;
                faces.isSeenByPoint=false;
                faces.index=index;
                polytopeFaces.push_back(faces);
                
            }
            
        }
        
        index++;
        
    }

    POLYTOPEFACES& U4DPolytope::closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<polytopeFaces.size(); i++) {
           
            //get normal of triangle
            U4DVector3n closestFace=polytopeFaces.at(i).triangle.closestPointOnTriangleToPoint(uPoint).toVector();
            
            //normalize
            closestFace.normalize();
            
            float closestDistance=polytopeFaces.at(i).triangle.pointA.toVector().dot(closestFace);
            
            if (closestDistance<distance) {
                
                distance=closestDistance;
                
                index=i;
                
            }
            
     }
        
        return polytopeFaces.at(index);
        
    }
    
    std::vector<POLYTOPEFACES>& U4DPolytope::getFacesOfPolytope(){
        
        return polytopeFaces;
    }
    
    std::vector<POLYTOPEEDGES>& U4DPolytope::getEdgesOfPolytope(){
     
        //for each face get its segments
        
    }
    
    std::vector<POLYTOPEVERTEX>& U4DPolytope::getVertexOfPolytope(){
        
        //for each face get its vertex
    }
    
    
    void U4DPolytope::removeAllFaces(){
        polytopeFaces.clear();
    }
    
    void U4DPolytope::show(){
        
        for (auto n:polytopeFaces) {
            n.triangle.show();
        }
        
    }
    
}