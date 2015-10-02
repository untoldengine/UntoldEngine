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
            
            
            
            //2. Load triangles to Polytope
          
            
            
            U4DVector3n faceNormal(0,0,0); //closest Normal
            
            while (iterationSteps<25) {
                
                //4. which face is closest to origin
                POLYTOPEFACES& face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                face.isSeenByPoint=true;
                
                //5. Get normal of face
                faceNormal=face.triangle.getTriangleNormal();
                
                
                faceNormal.normalize();
                //6. Get simplex point
                
                
                simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, faceNormal);
                
                float d=simplexPoint.minkowskiPoint.toVector().dot(faceNormal);
                
                float faceNormalMagnitude=faceNormal.magnitude();
                
                //7. check if need to exit loop
                if (d-faceNormalMagnitude<0.001) {
                    
                    //break from loop
                    break;
                    
                }
                
                //8. Which faces is seen by simplex point
                
                
                //9. build polytope with triangles seen by point
                
               
                
                //11. Remove duplicate faces
                
                
                
                //12. go back to 4
                
                iterationSteps++;
                
            }
            //13. if exit loop, get barycentric points
           
            
            
      }//end if Q==4
        
    }//end method
   

}