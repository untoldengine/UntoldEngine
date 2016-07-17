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
            
            //process face
            face.triangle=uTriangle;
            face.isSeenByPoint=false;
            face.index=index;
            
            //add face
            polytopeFaces.push_back(face);
            
          
            
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
    
    std::vector<POLYTOPEVERTEX> U4DPolytope::getPolytopeVertices(){
     
        std::vector<U4DVector3n> verticesBucket;
        polytopeVertices.clear();
        
        if (polytopeEdges.size()>0) {
            
            bool isDuplicate=false;
            
            //get the first segmet in the polytope
            U4DSegment firstSegment=polytopeEdges.at(0).segment;
            
            //get the points of the segmet
            
            std::vector<U4DPoint3n> segmentPoints=firstSegment.getPoints();
            
            //load the first points into the bucket
            for(auto n:segmentPoints){
                verticesBucket.push_back(n.toVector());
            }
            
            //Get the rest of the points and load them into the bucket if they don't exist
            for(auto n:polytopeEdges){
                
                std::vector<U4DPoint3n> restOfPoints=n.segment.getPoints();
                
                //for each new point, compare if they exist in the bucket
                for(auto m:restOfPoints){
                    
                    isDuplicate=false;
                    
                    for(auto p:verticesBucket){
                        
                        //if the points are equal, don't add them
                        if (m.toVector()==p) {
                            
                            isDuplicate=true;
                            
                        }//end if
                        
                    }//end for
                    
                    if (isDuplicate==false) {
                        verticesBucket.push_back(m.toVector());
                        
                    }//end if
                    
                }//end for
                
                
            }//end for
            
        }
        
        for(auto n:verticesBucket){
            
            POLYTOPEVERTEX vertices;
            vertices.vertex=n;
            
            polytopeVertices.push_back(vertices);
        }
        
        return polytopeVertices;
        
    }
    
    
    std::vector<POLYTOPEEDGES> U4DPolytope::getPolytopeSegments(){
        
        
        std::vector<U4DSegment> segmentBucket;
        polytopeEdges.clear();
        
        if (polytopeFaces.size()>0) {
            
            bool isDuplicate=false;
            
            //get the first face in the polytope
            U4DTriangle firstFace=polytopeFaces.at(0).triangle;
            
            //get the segments of the triangle
            
            std::vector<U4DSegment> firstSegments=firstFace.getSegments();
            
            //load the first segments into the bucket
            for(auto n:firstSegments){
                segmentBucket.push_back(n);
            }
            
            //Get the rest of the segments and load them into the bucket if they don't exist
            for(auto n:polytopeFaces){
                
                std::vector<U4DSegment> restOfSegments=n.triangle.getSegments();
                
                //for each new segment, compare if they exist in the bucket
                for(auto m:restOfSegments){
                    
                    isDuplicate=false;
                    
                    for(auto p:segmentBucket){
                        
                        //if the segments are equal, don't add them
                        if (m==p || m==p.negate()) {
                            
                            isDuplicate=true;
                        }//end if
                    }//end for
                    
                    if (isDuplicate==false) {
                        segmentBucket.push_back(m);
                        
                    }//end if
                    
                }//end for
                
                
            }//end for
        
            
        }
        
        for(auto n:segmentBucket){
        
            POLYTOPEEDGES edge;
            edge.segment=n;
            
            polytopeEdges.push_back(edge);
        }
        
        return polytopeEdges;
        
    }
    
    
    std::vector<POLYTOPEFACES>& U4DPolytope::getPolytopeFaces(){
            
            return polytopeFaces;
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