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
        
        if(uQ.size()==4){
            
        int iterationSteps=0; //to avoid infinite loop
            
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
        
        
        while (iterationSteps<25) {
            
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
            
            //4. update the upperbound
            upperBound=MIN(upperBound, penetrationVector.dot(faceNormalDirection));
            
            //4. If this point is no further from the origin than the picked triangle then go to step 7.
            if (upperBound-faceNormalDirection.magnitudeSquare()<0.001) {
                break;  //break from loop
            }
            
            //5. Remove all faces from the polytope that can be seen by this new point, this will create a hole
            // that must be filled with new faces built from the new support point in the remaining points from the old faces.
            
            removeAllFacesSeenByPoint(polytope, v.minkowskiPoint);
            
            createNewFacesToTheSimplex(polytope, v.minkowskiPoint);
            
            iterationSteps++;
            //6. Go to step 2
        }
        
        //7. Use the current closest triangle to the origin to extrapolate the contact information
        penetrationVector.show();
        
        
        }
    }
    
    void U4DEPAAlgorithm::removeAllFacesSeenByPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint){
        
        //what faces are seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        std::vector<U4DSegment> tempEdgesList;
        std::vector<U4DSegment> tempNegateEdges;
        
        //we need to remove all faces seen by the point
        
        for (int i=0; i<uPolytope.faces.size(); i++) {
            
            if (uPolytope.faces.at(i).directionOfTriangleNormalToPoint(uPoint)<0) { //if dot<0, then face not seen by point, so save these faces and delete the others
                
                facesNotSeenByPoint.push_back(uPolytope.faces.at(i));
                
            }else{ //else the face is seen by point, so save their edges and see if they are already in the container
                
                U4DSegment ab(uPolytope.faces.at(i).pointA,uPolytope.faces.at(i).pointB);
                U4DSegment ac(uPolytope.faces.at(i).pointA,uPolytope.faces.at(i).pointC);
                U4DSegment bc(uPolytope.faces.at(i).pointB,uPolytope.faces.at(i).pointC);
                
                tempEdgesList.push_back(ab);
                tempEdgesList.push_back(ac);
                tempEdgesList.push_back(bc);
                
                tempNegateEdges.push_back(ab.negate());
                tempNegateEdges.push_back(ac.negate());
                tempNegateEdges.push_back(bc.negate());
                
            }
        }
        
        //clear faces
        uPolytope.faces.clear();
        
        //copy faces with faces not seen by point
        uPolytope.faces=facesNotSeenByPoint;
        
        
        
        
    }
    
    void U4DEPAAlgorithm::createNewFacesToTheSimplex(U4DPolytope& uPolytope, U4DPoint3n& uPoint){
        
        //create new faces from the edges
        
        
        for (int i=0; i<uPolytope.edgesList.size(); i++) {
            
            //get points from edges/segments
            
            U4DPoint3n a=uPolytope.edgesList.at(i).pointA;
            U4DPoint3n b=uPolytope.edgesList.at(i).pointB;
            
            //create triangles
            U4DTriangle triangle(a,b,uPoint);
            
            //add to faces
            uPolytope.faces.push_back(triangle);
            
        }
        
        
    }
    
    
}