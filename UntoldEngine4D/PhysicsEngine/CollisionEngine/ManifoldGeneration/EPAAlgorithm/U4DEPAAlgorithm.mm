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

namespace U4DEngine{
    
    void U4DEPAAlgorithm::determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ){
        
        if(uQ.size()==4){
            
            
            U4DPolytope polytope;
            
            //get bounding volume for each model
            U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
            U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
            
            U4DPoint3n origin(0.0,0.0,0.0);
            int iterationSteps=0; //to avoid infinite loop
            
            //1. Build tetrahedron from Q
            U4DTetrahedron tetrahedron(uQ.at(0).minkowskiPoint,uQ.at(1).minkowskiPoint,uQ.at(2).minkowskiPoint,uQ.at(3).minkowskiPoint);
            
            //2. get triangles of tetrahedron
            std::vector<U4DTriangle> triangles=tetrahedron.getTrianglesOfTetrahedron();
            
            
            //3. Load triangles to Polytope
            
            for (int i=0; i<triangles.size(); i++) {
                
                polytope.addTriangleToPolytope(triangles.at(i));
            }
            
            while (iterationSteps<25) {
                
                //4. which face is closest to origin
                U4DTriangle closestTriangle=polytope.closestTriangleOnPolytopeToPoint(origin);
                
                //5. Get normal of face
                U4DVector3n normal=closestTriangle.getTriangleNormal();

                normal.normalize();
                
                float dist=normal.magnitude();
                
                //6. Get simplex point
                
                U4DSimplexStruct simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, normal);
                
                //7. check if need to exit loop
                if (simplexPoint.minkowskiPoint.toVector().dot(normal)-dist<0.0001) {
                
                    //break from loop
                    break;
                }
                
                //8. Which faces is seen by simplex point
                
                std::vector<U4DTriangle> trianglesInPolytope=polytope.getTrianglesOfPolytope();
                
                //faces container
                std::vector<U4DTriangle> trianglesSeenByPoint;
                
                for (int i=0; i<trianglesInPolytope.size(); i++) {
                    
                    U4DTriangle triangle=trianglesInPolytope.at(i);
                    
                    U4DVector3n triangleNormal=(triangle.pointA-triangle.pointB).cross(triangle.pointA-triangle.pointC);
                    
                    if (triangleNormal.dot(triangle.pointA-simplexPoint.minkowskiPoint)>=0) { //if dot>0, then face seen by point
                        
                        trianglesSeenByPoint.push_back(triangle);
                    }
                
                //9. build tetrahedron with triangles seen by point
                
                    for (int i=0; i<trianglesSeenByPoint.size(); i++) {
                        
                        U4DTriangle triangle=trianglesSeenByPoint.at(i);
                        
                        std::vector<U4DPoint3n> vertices=triangle.getTriangleVertices();
                        
                        U4DTetrahedron tetrahedron(vertices.at(0),vertices.at(1),vertices.at(2),simplexPoint.minkowskiPoint);
                        
                        
                        std::vector<U4DTriangle> triangles=tetrahedron.getTrianglesOfTetrahedron();
                        
                        
                        //10. Load triangles to Polytope
                        
                        for (int i=0; i<triangles.size(); i++) {
                            
                            polytope.addTriangleToPolytope(triangles.at(i));
                        }
                        
                    }
                    
                //11. go back to 4
                    
                  iterationSteps++;
            }
                
            //12. if exit loop, get barycentric points
            simplexPoint.minkowskiPoint.show();
                
            /*
            int iterationSteps=0; //to avoid infinite loop
            
            
            U4DVector3n n(0,0,0); //normal plane
            
            std::vector<Edges> removedFaceSavedEdges; //saved edges from the removed faces
            std::vector<U4DSegment> edgeList; //final set of saved edges
            
            //get bounding volume for each model
            U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
            U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
            
            U4DPoint3n origin(0.0,0.0,0.0);
            
            U4DPoint3n a(0,0,0);
            U4DPoint3n b(0,0,0);
            U4DPoint3n c(0,0,0);
            
            U4DTriangle face(a,b,c);
            
            U4DSimplexStruct simplexPoint;
            
            //steps
            
            //1. Build the initial polytope from the tetrahedron  produced by GJK
            U4DPolytope polytope(uQ);
            
            
            while (iterationSteps<25) {
                
                removedFaceSavedEdges.clear();
                edgeList.clear();
                
                //2. Pick the closest triangle of the polytope to the origin
                face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                //3. Generate the next point to be included in the polytope by getting the support point in the direction of the picked
                //triangle's normal
                n=(face.pointA-face.pointC).cross(face.pointA-face.pointB);
                
                n.normalize();
                
                float dist=n.magnitude();
                
                simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, n);
                
                
                //4. If this point is no further from the origin than the picked triangle then go to step 7.
                if (simplexPoint.minkowskiPoint.toVector().dot(n)-dist<0.0001) {
                //if(simplexPoint.minkowskiPoint.toVector().dot(n)<0 || simplexPoint.minkowskiPoint==tempW){
                    break;  //break from loop
                }
            
                //5. Remove all faces from the polytope that can be seen by this new point, this will create a hole
                // that must be filled with new faces built from the new support point in the remaining points from the old faces.
                
                removeAllFacesSeenByPoint(polytope, simplexPoint.minkowskiPoint,removedFaceSavedEdges);
                
                removeEdgesInPolytope(polytope,removedFaceSavedEdges,edgeList);
                
                createNewPolytopeFacesToPoint(polytope, simplexPoint.minkowskiPoint,edgeList);
                
                iterationSteps++;
                //6. Go to step 2
            }
            
            //7. Use the current closest triangle to the origin to extrapolate the contact information
            simplexPoint.minkowskiPoint.show();
            
             */
        }
            
      }
    }
}