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
            U4DSimplexStruct simplexPoint;
            
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
                
                polytope.addFaceToPolytope(triangles.at(i));
            }
            
            
            
            float u=FLT_MAX;
            U4DVector3n closestNormal(0,0,0); //closest Normal
            
            while (iterationSteps<25) {
                
                //4. which face is closest to origin
                POLYTOPEFACES& face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                face.isSeenByPoint=true;
                
                
                //5. Get normal of face
                closestNormal=face.triangle.getTriangleNormal();
                
                //6. Get simplex point
                
                simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, closestNormal);
                
                closestNormal.normalize();
                
                float directionVector=simplexPoint.minkowskiPoint.toVector().dot(closestNormal);
                
                u=MIN(u, directionVector);
                
                float closestPointMagnitude=simplexPoint.minkowskiPoint.magnitude();
                
                //7. check if need to exit loop
                if (closestPointMagnitude-u<0.0001) {
                    
                    //break from loop
                    break;
                    
                }
                
                //8. Which faces is seen by simplex point
                
                std::vector<POLYTOPEFACES>& trianglesInPolytope=polytope.getFacesOfPolytope();
                
                //faces container
                std::vector<U4DTriangle> trianglesSeenByPoint;
                
                for (int n=0; n<trianglesInPolytope.size(); n++) {
                    
                    U4DTriangle triangle=trianglesInPolytope.at(n).triangle;
                    
                    U4DVector3n triangleNormal=(triangle.pointA-triangle.pointB).cross(triangle.pointA-triangle.pointC);
                    
                    if (triangleNormal.dot(triangle.pointA-simplexPoint.minkowskiPoint)>=0) { //if dot>0, then face seen by point
                        
                        trianglesInPolytope.at(n).isSeenByPoint=true;
                        trianglesSeenByPoint.push_back(triangle);
                    }
                    
                }
                //9. build tetrahedron with triangles seen by point
                
                for (int i=0; i<trianglesSeenByPoint.size(); i++) {
                    
                    U4DTriangle triangle=trianglesSeenByPoint.at(i);
                    
                    std::vector<U4DPoint3n> vertices=triangle.getTriangleVertices();
                    
                    U4DTetrahedron newTetrahedron(vertices.at(0),vertices.at(1),vertices.at(2),simplexPoint.minkowskiPoint);
                    
                    std::vector<U4DTriangle> newTriangles=newTetrahedron.getTrianglesOfTetrahedron();
                    
                    
                    //10. Load triangles to Polytope
                    
                    for (int j=0; j<newTriangles.size(); j++) {
                        
                        polytope.addFaceToPolytope(newTriangles.at(j));
                    }
                    
                }
                
                //11. Remove duplicate faces
                trianglesInPolytope.erase(std::remove_if(trianglesInPolytope.begin(), trianglesInPolytope.end(),[](POLYTOPEFACES &p){ return p.isSeenByPoint;} ),trianglesInPolytope.end());
                
                
                
                //12. go back to 4
                
                iterationSteps++;
                
            }
            //13. if exit loop, get barycentric points
            simplexPoint.minkowskiPoint.show();
            
      }//end if Q==4
        
    }//end method
   

}