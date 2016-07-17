//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"
#include <algorithm>
#include "U4DTriangle.h"
#include "U4DSegment.h"
#include "U4DPoint3n.h"
#include "U4DVector3n.h"



namespace U4DEngine {
    
    U4DPolytope::U4DPolytope():index(0){
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }
    
    void U4DPolytope::addPolytopeFace(POLYTOPEFACES &uFace, U4DTriangle& uTriangle){
        
        //process face
        uFace.triangle=uTriangle;
        uFace.isSeenByPoint=false;
        uFace.index=index;
                
        //add face
        polytopeFaces.push_back(uFace);

    }
    
    void U4DPolytope::addPolytopeEdges(POLYTOPEFACES &uFace, U4DTriangle& uTriangle){
        
        //process edges
        std::vector<U4DSegment> segments=uTriangle.getSegments();
        
        POLYTOPEEDGES ab;
        POLYTOPEEDGES bc;
        POLYTOPEEDGES ca;
        
        ab.isDuplicate=false;
        bc.isDuplicate=false;
        ca.isDuplicate=false;
        
        ab.segment=segments.at(0);
        bc.segment=segments.at(1);
        ca.segment=segments.at(2);
        
        //add edges
        uFace.edges.push_back(ab);
        uFace.edges.push_back(bc);
        uFace.edges.push_back(ca);
        
        
    }
    
    void U4DPolytope::addPolytopeVertices(POLYTOPEFACES &uFace, U4DTriangle& uTriangle){
        
        //process vertices
        POLYTOPEVERTEX pointA;
        pointA.vertex=uTriangle.pointA.toVector();
        
        POLYTOPEVERTEX pointB;
        pointB.vertex=uTriangle.pointB.toVector();
        
        POLYTOPEVERTEX pointC;
        pointC.vertex=uTriangle.pointC.toVector();
        
        pointA.isDuplicate=false;
        pointB.isDuplicate=false;
        pointC.isDuplicate=false;
        
        
        //add vertices
        uFace.vertices.push_back(pointA);
        uFace.vertices.push_back(pointB);
        uFace.vertices.push_back(pointC);
        
    }
    
    void U4DPolytope::addPolytopeData(U4DTriangle& uTriangle){
        
        bool triangleExist=false;
        
        //check if triangle exist, if it does, do not add it
        for (auto &currentfaces:polytopeFaces) {
        
            if (currentfaces.triangle==uTriangle) {
                
                triangleExist=true;
                
                break;
            }
        }
        
        if (triangleExist==false) { //if triangle does not exist, then add it
            
            //process face
            POLYTOPEFACES face;
            
            addPolytopeFace(face, uTriangle);
            
            addPolytopeEdges(face, uTriangle);
            
            addPolytopeVertices(face, uTriangle);
            
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
     
        return polytopeEdges;
    }
    
    std::vector<POLYTOPEVERTEX>& U4DPolytope::getVertexOfPolytope(){

        return polytopeVertex;
    }
    
    void U4DPolytope::cleanUp(){
        
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