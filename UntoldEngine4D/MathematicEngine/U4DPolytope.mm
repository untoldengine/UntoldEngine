//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"

namespace U4DEngine {
    
    U4DPolytope::U4DPolytope(std::vector<U4DSimplexStruct> uQ){
        //build polytope from simplex points
        
        faces.clear();
        edgesList.clear();
        
        int m=4;    //set m to initial size of tetrahedron simplex
        
        int n=0;
        
        while (m<=uQ.size()) {
            
            U4DPoint3n a=uQ.at(n).minkowskiPoint;
            U4DPoint3n b=uQ.at(n+1).minkowskiPoint;
            U4DPoint3n c=uQ.at(n+2).minkowskiPoint;
            U4DPoint3n d=uQ.at(n+3).minkowskiPoint;
            
            U4DTriangle abc(a,b,c);
            U4DTriangle abd(a,b,d);
            U4DTriangle acd(a,c,d);
            U4DTriangle bcd(b,c,d);
            
            faces.push_back(abc);
            faces.push_back(abd);
            faces.push_back(acd);
            faces.push_back(bcd);
            
            m=m+1;
            n=n+1;
            
        }
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }

    U4DTriangle U4DPolytope::closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<faces.size(); i++) {
            
            float triangleDistanceToOrigin=faces.at(i).squareDistanceOfClosestPointOnTriangleToPoint(uPoint);
            
            if (triangleDistanceToOrigin<=distance) {
                
                distance=triangleDistanceToOrigin;
                
                index=i;
            }
        }
        
        return faces.at(index);
        
    }
    
    void U4DPolytope::removeAllFacesSeenByPoint(U4DPoint3n& uPoint){
        
        //what faces are seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        //we need to remove all faces seen by the point
        
        for (int i=0; i<faces.size(); i++) {
            
            if (faces.at(i).directionOfTriangleNormalToPoint(uPoint)<0) { //if dot<0, then face not seen by point, so save these faces and delete the others
                
                facesNotSeenByPoint.push_back(faces.at(i));
                
            }else{
                
                //save the edges of the triangles which will be removed
                U4DSegment ab(faces.at(i).pointA,faces.at(i).pointB);
                U4DSegment ac(faces.at(i).pointA,faces.at(i).pointC);
                U4DSegment bc(faces.at(i).pointB,faces.at(i).pointC);
                
                
                if (edgesList.size()==0) { //if edgelist is empty, add edges
                    
                    edgesList.push_back(ab);
                    edgesList.push_back(ac);
                    edgesList.push_back(bc);
                    
                }else{ //if edgelist not empty
                   
                    std::vector<U4DSegment> edgeListCopy;
                    std::vector<U4DSegment> tempEdgeList{ab,ac,bc};
                    std::vector<U4DSegment> negateTempEdgeList{ab.negate(),ac.negate(),bc.negate()};
                    
                    //copy edge list
                    edgeListCopy=edgesList;
                    /*
                     if edge in opposite direction exist, edge is removed and new edge is not added
                     */
                    
                    for (int i=0; i<negateTempEdgeList.size(); i++) {
                        
                        for (int j=0; j<edgesList.size(); j++) {
                            
                            if (negateTempEdgeList.at(i)==edgesList.at(j)) { //if edge in opposite direction exist
                                
                                //remove edge
                                edgeListCopy.erase(edgeListCopy.begin()+j);
                                
                            }else{
                                
                                //add edge to edge list
                                edgeListCopy.push_back(tempEdgeList.at(i));
                                
                            }
                        }
                    }
                 
                    //clear edge list
                    edgesList.clear();
                    
                    //copy new updated list to edgelist
                    edgesList=edgeListCopy;
                    
                }
                
                
            }
        }
        
        //clear faces
        faces.clear();
        
        //copy faces with faces not seen by point
        faces=facesNotSeenByPoint;
        
        
    }
    
    void U4DPolytope::createNewFacesToTheSimplex(U4DPoint3n& uPoint){
        
        //create new faces from the edges
        
        
        for (int i=0; i<edgesList.size(); i++) {
            
            //get points from edges/segments

            U4DPoint3n a=edgesList.at(i).pointA;
            U4DPoint3n b=edgesList.at(i).pointB;
            
            //create triangles
            U4DTriangle triangle(a,b,uPoint);
            
            //add to faces
            faces.push_back(triangle);
            
        }
        
        
    }

    
}