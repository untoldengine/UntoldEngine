//
//  U4DEPAAlgorithm.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DEPAAlgorithm.h"
#include "U4DTriangle.h"
#include "U4DTetrahedron.h"
#include "U4DPolytope.h"

namespace U4DEngine{
    
    void U4DEPAAlgorithm::determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ){
        
        //upper bound set to infinity
        float upperBound=FLT_MAX;
        U4DVector3n faceNormalDirection(0,0,0);
        U4DVector3n penetrationVector(0,0,0);
        
        //get bounding volume for each model
        U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
        U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
        
        U4DPoint3n origin(0.0,0.0,0.0);
        
        
        //steps
        
        //1. Build the initial polytope from the tetrahedron  produced by GJK
        U4DPolytope polytope(uQ);
        
        
        while (upperBound-faceNormalDirection.magnitudeSquare()<0.001) {
            
            //2. Pick the closest triangle of the polytope to the origin
            U4DTriangle face=polytope.closestFaceOnPolytopeToPoint(origin);
            
            //3. Generate the next point to be included in the polytope by getting the support point in the direction of the picked
            //triangle's normal
            faceNormalDirection=(face.pointA-face.pointB).cross(face.pointA-face.pointC);
            
            if (faceNormalDirection.dot(origin.toVector())>0) { //if normal in same direction as origin, then negate normal
                faceNormalDirection.negate();
            }
            
            //normalize the normal
            faceNormalDirection.normalize();
            
            U4DSimplexStruct v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, faceNormalDirection);
           
            penetrationVector=v.minkowskiPoint.toVector();
            
            //4. If this point is no further from the origin than the picked triangle then go to step 7.
            
            
            //4. update the upperbound
            upperBound=MIN(upperBound, penetrationVector.dot(faceNormalDirection));
            
            //5. Remove all faces from the polytope that can be seen by this new point, this will create a hole
            // that must be filled with new faces built from the new support point in the remaining points from the old faces.
            
            polytope.removeAllFacesSeenByPoint(v.minkowskiPoint);
            
            polytope.createNewFacesToTheSimplex(v.minkowskiPoint);
            
            
            //6. Go to step 2
        }
        
        //7. Use the current closest triangle to the origin to extrapolate the contact information
        penetrationVector.show();
        
        
    }
    
    U4DTriangle U4DEPAAlgorithm::closestTriangleOnPolytopeToPoint(U4DPoint3n& uPoint, std::vector<U4DSimplexStruct> uQ){
        
        //build triangles from the simplex container Q. Assume Q.size()>=4
        
        if (uQ.size()>=4) {
            
            
            
            
        }
        
    }
    
    
}