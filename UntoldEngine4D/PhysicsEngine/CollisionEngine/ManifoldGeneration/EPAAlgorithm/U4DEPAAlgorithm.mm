//
//  U4DEPAAlgorithm.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DEPAAlgorithm.h"
#include <algorithm>
#include "U4DTriangle.h"
#include "U4DTetrahedron.h"
#include "U4DPolytope.h"
#include "CommonProtocols.h"

namespace U4DEngine{
    
    
    
    void U4DEPAAlgorithm::determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ){
        
        if(uQ.size()==4){
                        
            U4DPolytope polytope;
            std::vector<POLYTOPEEDGES> edges;
            U4DVector3n faceNormal;
            float d;
            
            U4DSimplexStruct simplexPoint;
            
            //get bounding volume for each model
            U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
            U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
            
            U4DPoint3n origin(0.0,0.0,0.0);
            int iterationSteps=0; //to avoid infinite loop
            
            //1. Build tetrahedron from Q
            U4DTetrahedron tetrahedron(uQ.at(0).minkowskiPoint,uQ.at(1).minkowskiPoint,uQ.at(2).minkowskiPoint,uQ.at(3).minkowskiPoint);
            
            
    
            //2. get triangles of tetrahedron
            std::vector<U4DTriangle> triangles=tetrahedron.getTriangles();
            
            
            //3. Load triangles to Polytope
            
            for (auto face:triangles) {
                
                polytope.addFaceToPolytope(face);
                
            }
           
            
            while (iterationSteps<25) {
                
                //4. which face is closest to origin
                POLYTOPEFACES& face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                face.isSeenByPoint=true;
                
                //5. Get normal of face
                faceNormal=face.triangle.getTriangleNormal();
                
                faceNormal.normalize();
                //6. Get simplex point
                
                
                simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, faceNormal);
                
                d=simplexPoint.minkowskiPoint.toVector().dot(faceNormal);
                
                float faceNormalMagnitude=faceNormal.magnitude();
                
                //7. check if need to exit loop
                if (d-faceNormalMagnitude<0.001) {
                    
                    //break from loop
                    break;
                    
                }
                
                //8. Which faces is seen by simplex point
                for (auto face:polytope.getFacesOfPolytope()) {
                    
                    U4DVector3n triangleNormal=(face.triangle.pointA-face.triangle.pointC).cross(face.triangle.pointA-face.triangle.pointB);
                    
                    if (triangleNormal.dot(simplexPoint.minkowskiPoint.toVector())>=0) { //if dot>0, then face seen by point
                        
                        face.isSeenByPoint=true;
                        
                        //add segments into container
                        POLYTOPEEDGES ab;
                        POLYTOPEEDGES bc;
                        POLYTOPEEDGES ca;
                        
                        ab.segment=face.triangle.segmentAB.negate();
                        bc.segment=face.triangle.segmentBC.negate();
                        ca.segment=face.triangle.segmentAC.negate();
                        
                        ab.isDuplicate=false;
                        bc.isDuplicate=false;
                        ca.isDuplicate=false;
                        
                        std::vector<POLYTOPEEDGES> tempEdges{ab,bc,ca};
                        
                        if (edges.size()==0) {
                            
                            edges=tempEdges;
                            
                        }else{
                            
                            for (auto& tempEdge:tempEdges) {
                                
                                for (auto& edge:edges) {
                                    
                                    if (tempEdge.segment==edge.segment.negate()) {
                                        
                                        tempEdge.isDuplicate=true;
                                        edge.isDuplicate=true;
                                        
                                    }//end if
                                    
                                }//end for
                                
                            }//end for
                            
                            
                            edges.push_back(ab);
                            edges.push_back(bc);
                            edges.push_back(ca);
                            
                        }//end if
                        
                    }//end if
                }
                
                //9. Remove duplicate faces and edges
                
                polytope.polytopeFaces.erase(std::remove_if(polytope.polytopeFaces.begin(), polytope.polytopeFaces.end(),[](POLYTOPEFACES &p){ return p.isSeenByPoint;} ),polytope.polytopeFaces.end());
                
                edges.erase(std::remove_if(edges.begin(), edges.end(),[](POLYTOPEEDGES &e){ return e.isDuplicate;} ),edges.end());
                
                //10. build polytope with triangles seen by point
                
                for (auto edge:edges) {
                    
                    U4DTriangle triangle(simplexPoint.minkowskiPoint,edge.segment.pointA,edge.segment.pointB);
                    polytope.addFaceToPolytope(triangle);
                    
                }
               
                
                //12. go back to 4
                
                iterationSteps++;
                
            }
            //13. if exit loop, get barycentric points
            
           std::cout<<"Penetration: "<<d<<std::endl;
            std::cout<<"Normal: "<<std::endl;
            faceNormal.show();
            
            
      }//end if Q==4
        
    }//end method
   

}