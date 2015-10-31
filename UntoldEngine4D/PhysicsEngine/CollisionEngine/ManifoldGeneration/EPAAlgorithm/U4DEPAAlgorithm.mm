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
    
    void U4DEPAAlgorithm::determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ){
        
        //get bounding volume for each model
        U4DBoundingVolume *boundingVolume1=uModel1->convexHullBoundingVolume;
        U4DBoundingVolume *boundingVolume2=uModel2->convexHullBoundingVolume;
        
        
        //blow up simplex to tetrahedron
        
        //test if origin is in tetrahedron
       
        if(uQ.size()==4){
                        
            U4DPolytope polytope;
            std::vector<POLYTOPEEDGES> edges;
            U4DVector3n faceNormal;
            float penetrationDepth;
            
            U4DSimplexStruct simplexPoint;
            
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
           
            
            while (iterationSteps<10 && polytope.polytopeFaces.size()>0) {
                
                //4. which face is closest to origin
                POLYTOPEFACES& face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                face.isSeenByPoint=true;
                
                //5. Get normal of face
                faceNormal=face.triangle.getTriangleNormal();
                
                faceNormal.normalize();
                //6. Get simplex point
                
                
                simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, faceNormal);
                
                penetrationDepth=simplexPoint.minkowskiPoint.toVector().dot(faceNormal);
                
                float faceNormalMagnitude=faceNormal.magnitude();
                
                //7. check if need to exit loop
                if (penetrationDepth-faceNormalMagnitude<0.0001) {
                    
                    //break from loop
                    break;
                    
                }
                
                //8. Which faces is seen by simplex point
                for (auto face:polytope.getFacesOfPolytope()) {
                    
                    U4DVector3n triangleNormal=(face.triangle.pointA-face.triangle.pointB).cross(face.triangle.pointA-face.triangle.pointC);
                
                    if (triangleNormal.dot(simplexPoint.minkowskiPoint.toVector())>=0) { //if dot>0, then face seen by point
                        
                        face.isSeenByPoint=true;
                        
                        //add segments into container
                        POLYTOPEEDGES ab;
                        POLYTOPEEDGES bc;
                        POLYTOPEEDGES ca;
                        
                        ab.segment=face.triangle.segmentAB;
                        bc.segment=face.triangle.segmentBC;
                        ca.segment=face.triangle.segmentCA;
                        
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
                            
                            //store the edges
                            edges.push_back(tempEdges.at(0));
                            edges.push_back(tempEdges.at(1));
                            edges.push_back(tempEdges.at(2));
                            
                        }//end if
                        
                    }//end if
                }
               
                //9. Remove duplicate faces and edges
                
                polytope.polytopeFaces.erase(std::remove_if(polytope.polytopeFaces.begin(), polytope.polytopeFaces.end(),[](POLYTOPEFACES &p){ return p.isSeenByPoint;} ),polytope.polytopeFaces.end());
                
                std::cout<<"size of polytope: "<<polytope.polytopeFaces.size()<<std::endl;
                
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
            uModel1->collisionProperties.contactManifoldInformation.penetrationDepth=penetrationDepth;
            uModel1->collisionProperties.contactManifoldInformation.lineOfAction=faceNormal;
            
            uModel2->collisionProperties.contactManifoldInformation.penetrationDepth=penetrationDepth;
            uModel2->collisionProperties.contactManifoldInformation.lineOfAction=faceNormal;
            
            
      }//end if Q==4
        
    }//end method
   

    void U4DEPAAlgorithm::verifySimplexStructForEPA(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2, std::vector<U4DSimplexStruct>& uQ){
        
        //get size of Q
        int simplexStructSize=uQ.size();
        
        //if Q size is a point
        if (simplexStructSize==1) {
        
         //if Q size is a segment
        }else if (simplexStructSize==2){
            
            constructSimplexStructForSegment(uBoundingVolume1,uBoundingVolume2,uQ);
            
        //if Q size is a triangle
        }else if (simplexStructSize==3){
            
            constructSimplexStructForTriangle(uBoundingVolume1,uBoundingVolume2,uQ);
        }
        
    }
    
    bool U4DEPAAlgorithm::constructSimplexStructForSegment(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume *uBoundingVolume2,std::vector<U4DSimplexStruct>& uQ){
        
        U4DVector3n tangentVector1;
        U4DVector3n directionVector0;
        U4DPoint3n origin(0.0,0.0,0.0);
        
        U4DSimplexStruct simplexPointA=uQ.at(0);
        U4DSimplexStruct simplexPointB=uQ.at(1);
        
        U4DVector3n ab=simplexPointA.minkowskiPoint-simplexPointB.minkowskiPoint;
        
        //normalize the vector
        ab.normalize();
        
        //find an orthonormal basis to vector ab
        ab.computeOrthonormalBasis(tangentVector1, directionVector0);
        
        //rotate directionVector0 60 degrees about ab
        
        U4DVector3n directionVector1=directionVector0.rotateVectorAboutAngleAndAxis(60, ab);
        
        //rotate directionVector1 60 degrees about directionVector2
        
        U4DVector3n directionVector2=directionVector1.rotateVectorAboutAngleAndAxis(60, ab);
        
        
        //use directionVector0 as a direction vector to find the support point
        
        U4DSimplexStruct simplexPoint0=calculateSupportPointInDirection(uBoundingVolume1, uBoundingVolume2, directionVector0);
        
        ////use directionVector1 as a direction vector to find the support point
        U4DSimplexStruct simplexPoint1=calculateSupportPointInDirection(uBoundingVolume1, uBoundingVolume2, directionVector1);
        
        //use directionVector2 as a direction vector to find the support point
        U4DSimplexStruct simplexPoint2=calculateSupportPointInDirection(uBoundingVolume1, uBoundingVolume2, directionVector2);
        
        //Now you can build two tetrahedron: aX0X1X2 and bX0X1X2, now find out in which tetrahedron the origin is contained
        
        U4DTetrahedron tetrahedronA012(simplexPointA.minkowskiPoint,simplexPoint0.minkowskiPoint,simplexPoint1.minkowskiPoint,simplexPoint2.minkowskiPoint);

        U4DTetrahedron tetrahedronB012(simplexPointB.minkowskiPoint,simplexPoint0.minkowskiPoint,simplexPoint1.minkowskiPoint,simplexPoint2.minkowskiPoint);

        
        if (tetrahedronA012.isPointInTetrahedron(origin)) {
            
            //load up Q with values
            uQ.clear();
            
            uQ.push_back(simplexPointA);
            uQ.push_back(simplexPoint0);
            uQ.push_back(simplexPoint1);
            uQ.push_back(simplexPoint2);
            //tetrahedron was able to be form from points
            return true;
        }else if (tetrahedronB012.isPointInTetrahedron(origin)){
            
            //load up Q with values
            uQ.clear();
            
            uQ.push_back(simplexPointB);
            uQ.push_back(simplexPoint0);
            uQ.push_back(simplexPoint1);
            uQ.push_back(simplexPoint2);
            //tetrahedron was able to be form from points
            return true;
            
        }else{
            
            //tetrahedron was not able to be form from points
            return false;
        }
        
    }
    
    bool U4DEPAAlgorithm::constructSimplexStructForTriangle(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2,std::vector<U4DSimplexStruct>& uQ){
        
        U4DPoint3n origin(0.0,0.0,0.0);
        
        U4DSimplexStruct simplexPointA=uQ.at(0);
        U4DSimplexStruct simplexPointB=uQ.at(1);
        U4DSimplexStruct simplexPointC=uQ.at(2);
        
        //get the normal vector of the triangle in clockwise and counterclockwise direction and use it as the direction vector for the
        //simplex points
        
        U4DVector3n directionVector0=(simplexPointA.minkowskiPoint-simplexPointB.minkowskiPoint).cross(simplexPointA.minkowskiPoint-simplexPointC.minkowskiPoint);
        
        U4DVector3n directionVector1=(simplexPointA.minkowskiPoint-simplexPointC.minkowskiPoint).cross(simplexPointA.minkowskiPoint-simplexPointB.minkowskiPoint);
        
        
        //use directionVector0 as a direction vector to find the support point
        
        U4DSimplexStruct simplexPoint0=calculateSupportPointInDirection(uBoundingVolume1, uBoundingVolume2, directionVector0);
        
        //use directionVector1 as a direction vector to find the support point
        
        U4DSimplexStruct simplexPoint1=calculateSupportPointInDirection(uBoundingVolume1, uBoundingVolume2, directionVector1);
        
        //Now you can build two tetrahedron: ABC0 and ABC1, now find out in which tetrahedron the origin is contained
        
        U4DTetrahedron tetrahedronABC0(simplexPointA.minkowskiPoint,simplexPointB.minkowskiPoint,simplexPointC.minkowskiPoint,simplexPoint0.minkowskiPoint);
        
        U4DTetrahedron tetrahedronABC1(simplexPointA.minkowskiPoint,simplexPointB.minkowskiPoint,simplexPointC.minkowskiPoint,simplexPoint1.minkowskiPoint);
        
        
        if (tetrahedronABC0.isPointInTetrahedron(origin)) {
            
            //load up Q with values
            uQ.clear();
            
            uQ.push_back(simplexPointA);
            uQ.push_back(simplexPointB);
            uQ.push_back(simplexPointC);
            uQ.push_back(simplexPoint0);
            //tetrahedron was able to be form from points
            return true;
            
        }else if (tetrahedronABC1.isPointInTetrahedron(origin)){
            
            //load up Q with values
            uQ.clear();
            
            uQ.push_back(simplexPointA);
            uQ.push_back(simplexPointB);
            uQ.push_back(simplexPointC);
            uQ.push_back(simplexPoint1);
            //tetrahedron was able to be form from points
            return true;
            
        }else{
            
            //tetrahedron was not able to be form from points
            return false;
        }

        
    }
    
    
}