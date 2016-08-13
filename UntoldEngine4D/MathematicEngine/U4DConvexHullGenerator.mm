//
//  U4DConvexHullGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DConvexHullGenerator.h"
#include "U4DPolytope.h"
#include "U4DTriangle.h"
#include "U4DSegment.h"
#include "CommonProtocols.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DConvexHullGenerator::U4DConvexHullGenerator(){
        
    }
    
    U4DConvexHullGenerator::~U4DConvexHullGenerator(){
        
    }
    
    CONVEXHULL U4DConvexHullGenerator::buildConvexHull(std::vector<U4DVector3n> &uVertices){
        
//        U4DPolytope polytope;
//        CONVEXHULL convexhull;
//        std::vector<POLYTOPEEDGES> edges;
//        
//        //1. Build tetrahedron. Make sure that tetrahedron is valid
//        HULLINITIALDATA hullInitialData=buildTetrahedron(uVertices);
//        
//        U4DTetrahedron tetrahedron=hullInitialData.tetrahedron;
//        
//        if (tetrahedron.isValid()) {
//            //2. get triangles of tetrahedron
//            std::vector<U4DTriangle> triangles=tetrahedron.getTriangles();
//            
//            //3. Load tetrahedron faces into Polytope
//            
//            for (auto face:triangles) {
//                
//                polytope.addPolytopeData(face);
//                
//            }
//            
//            
//            //4. for each left over vertex not part of the tetrahedron, determine if they are seen by any face
//            
//            for(auto n: hullInitialData.vertices){
//                
//                edges.clear();
//            
//                //Which faces is seen by point
//                for (auto &face:polytope.getPolytopeFaces()) {
//                    
//                    if (volumeSign(face.triangle, n.vertex)<0) { //is face seen by point
//                        
//                        face.isSeenByPoint=true;
//                        
//                        //add segments into container
//                        POLYTOPEEDGES ab;
//                        POLYTOPEEDGES bc;
//                        POLYTOPEEDGES ca;
//                        
//                        std::vector<U4DSegment> segments=face.triangle.getSegments();
//                        
//                        ab.segment=segments.at(0);
//                        bc.segment=segments.at(1);
//                        ca.segment=segments.at(2);
//                        
//                        ab.isDuplicate=false;
//                        bc.isDuplicate=false;
//                        ca.isDuplicate=false;
//                        
//                        std::vector<POLYTOPEEDGES> tempEdges{ab,bc,ca};
//                        
//                        if (edges.size()==0) {
//                            
//                            edges=tempEdges;
//                            
//                        }else{
//                            
//                            for (auto& tempEdge:tempEdges) {
//                                
//                                for (auto& edge:edges) {
//                                    
//                                    if (tempEdge.segment==edge.segment.negate()) {
//                                        
//                                        //set edges as duplicates
//                                        tempEdge.isDuplicate=true;
//                                        edge.isDuplicate=true;
//                                        
//                                        //set vertices as duplicates
//                                        
//                                        
//                                    }//end if
//                                    
//                                }//end for
//                                
//                            }//end for
//                            
//                            //store the edges
//                            edges.push_back(tempEdges.at(0));
//                            edges.push_back(tempEdges.at(1));
//                            edges.push_back(tempEdges.at(2));
//                            
//                        }//end if
//                        
//                    }//end if
//                }//end for
//                
//                //Remove duplicate faces and edges
//                
//                polytope.polytopeFaces.erase(std::remove_if(polytope.polytopeFaces.begin(), polytope.polytopeFaces.end(),[](POLYTOPEFACES &p){ return p.isSeenByPoint;} ),polytope.polytopeFaces.end());
//                
//                edges.erase(std::remove_if(edges.begin(), edges.end(),[](POLYTOPEEDGES &e){ return e.isDuplicate;} ),edges.end());
//                
//                //build polytope with triangles seen by point
//                
//                for (auto edge:edges) {
//                    
//                    U4DPoint3n point=n.vertex.toPoint();
//                    
//                    U4DTriangle triangle(point,edge.segment.pointA,edge.segment.pointB);
//                    
//                    polytope.addPolytopeData(triangle);
//                    
//                }
//                
//            }
//            
//            
//            //return convex hull
//            convexhull.faces=polytope.getPolytopeFaces();
//            convexhull.edges=polytope.getPolytopeSegments();
//            convexhull.vertex=polytope.getPolytopeVertices();
//            
//        }else{
//           
//            std::cout<<"Initial Tetrahedron used in Convex Hull generation is not valid. Make sure no points are collinear."<<std::endl;
//       
//        }
//        
//        
//        
//        return convexhull;

    }
    
    int U4DConvexHullGenerator::volumeSign(U4DTriangle &uTriangle, U4DVector3n &uVector){
        
//        float volume;
//        
//        float ax,ay,az,bx,by,bz,cx,cy,cz;
//        
//        ax=uTriangle.pointA.x-uVector.x;
//        ay=uTriangle.pointA.y-uVector.y;
//        az=uTriangle.pointA.z-uVector.z;
//        
//        bx=uTriangle.pointB.x-uVector.x;
//        by=uTriangle.pointB.y-uVector.y;
//        bz=uTriangle.pointB.z-uVector.z;
//        
//        cx=uTriangle.pointC.x-uVector.x;
//        cy=uTriangle.pointC.y-uVector.y;
//        cz=uTriangle.pointC.z-uVector.z;
//        
//        
//        volume=ax*(by*cz-bz*cy)+ay*(bz*cx-bx*cz)+az*(bx*cy-by*cx);
//        
//        //the volume should be an integer
//        if (volume>0.5) return 1;
//        else if(volume<-0.5) return -1;
//        else return 0;
        
    }
    
    HULLINITIALDATA U4DConvexHullGenerator::buildTetrahedron(std::vector<U4DVector3n> &uVertices){
        
//        std::vector<INITIALHULLVERTEX> validInitialHullVertex;
//        
//        HULLINITIALDATA initialHull;
//        
//        //copy all vertices to the temporary validtetraheronvertex
//        for(int i=0;i<uVertices.size();i++){
//            
//            INITIALHULLVERTEX tempInitialHullVertex;
//            tempInitialHullVertex.vertex=uVertices.at(i);
//            tempInitialHullVertex.isValid=false;
//            
//            validInitialHullVertex.push_back(tempInitialHullVertex);
//            
//        }
//        
//        //First three points of tetrahedron
//        U4DPoint3n pointA=validInitialHullVertex.at(0).vertex.toPoint();
//        U4DPoint3n pointB=validInitialHullVertex.at(1).vertex.toPoint();
//        U4DPoint3n pointC=validInitialHullVertex.at(2).vertex.toPoint();
//        
//        validInitialHullVertex.at(0).isValid=true;
//        validInitialHullVertex.at(1).isValid=true;
//        validInitialHullVertex.at(2).isValid=true;
//        
//        for(int i=3;i<validInitialHullVertex.size();i++){
//            
//            U4DPoint3n pointD=validInitialHullVertex.at(i).vertex.toPoint();
//            
//            U4DTetrahedron tempTetrahedron(pointA,pointB,pointC,pointD);
//        
//            if (tempTetrahedron.isValid()) {
//                validInitialHullVertex.at(i).isValid=true;
//                initialHull.tetrahedron=tempTetrahedron;
//                break;
//            }
//            
//        }
//        
//        //remove all vertexes that are valid. We don't need them anymore to compute the hull
//        validInitialHullVertex.erase(std::remove_if(validInitialHullVertex.begin(), validInitialHullVertex.end(),[](INITIALHULLVERTEX &p){ return p.isValid;} ),validInitialHullVertex.end());
//        
//        initialHull.vertices=validInitialHullVertex;
//        
//        //return valid hull
//        return initialHull;
        
    }
    
    bool U4DConvexHullGenerator::isValid(CONVEXHULL &uConvexHull){
        
//        //check that Vertices-Edges+Faces=2
//        
//        if ((uConvexHull.vertex.size()-uConvexHull.edges.size()+uConvexHull.faces.size())==2) {
//            return true;
//        }else{
//            
//            std::cout<<"Sorry dude, computed Convex Hull is not valid"<<std::endl;
//            return false;
//        }
    }
    
}