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
            
        std::vector<U4DSegment> edgesList;
      
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
        
        U4DPoint3n p(1,0.5,2);
        removeAllFacesSeenByPoint(polytope, p, edgesList);
        
        removeEdgesInPolytope(polytope,edgesList);
        
        createNewPolytopeFacesToPoint(polytope, p,edgesList);
            
        /*
        
        while (iterationSteps<25) {
            
            edgesList.clear();
            
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
            
            U4DEngine::U4DPoint3n a(0,0,0);
            U4DEngine::U4DPoint3n b(2,0,0);
            
            //4. update the upperbound
            upperBound=MIN(upperBound, penetrationVector.dot(faceNormalDirection));
            
            //4. If this point is no further from the origin than the picked triangle then go to step 7.
            if (upperBound-faceNormalDirection.magnitudeSquare()<0.001) {
                break;  //break from loop
            }
            
            //5. Remove all faces from the polytope that can be seen by this new point, this will create a hole
            // that must be filled with new faces built from the new support point in the remaining points from the old faces.
            
            removeAllFacesSeenByPoint(polytope, v.minkowskiPoint,edgesList);
            
            removeEdgesInPolytope(polytope,edgesList);
            
            createNewPolytopeFacesToPoint(polytope, v.minkowskiPoint,edgesList);
            
            iterationSteps++;
            //6. Go to step 2
        }
        */
        //7. Use the current closest triangle to the origin to extrapolate the contact information
        penetrationVector.show();
        
        
        }
    }
    
    void U4DEPAAlgorithm::removeAllFacesSeenByPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint,std::vector<U4DSegment>& uEdgesList){
        
        //what faces are seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        
        //we need to remove all faces seen by the point
        
        for (int i=0; i<uPolytope.faces.size(); i++) {
            
            if (uPolytope.faces.at(i).directionOfTriangleNormalToPoint(uPoint)>=0) { //if dot>=0, then face seen by point, so save these edges
                
                U4DSegment ab(uPolytope.faces.at(i).pointA,uPolytope.faces.at(i).pointB);
                U4DSegment ac(uPolytope.faces.at(i).pointB,uPolytope.faces.at(i).pointC);
                U4DSegment bc(uPolytope.faces.at(i).pointC,uPolytope.faces.at(i).pointA);
                
                uEdgesList.push_back(ab);
                uEdgesList.push_back(ac);
                uEdgesList.push_back(bc);
                
                
            }else{ //else the face is not seen by point, so save the face
                
               facesNotSeenByPoint.push_back(uPolytope.faces.at(i));
                
                
            }
        }
        
        //clear faces
        uPolytope.faces.clear();
        
        //copy faces with faces not seen by point
        uPolytope.faces=facesNotSeenByPoint;
        
    }
    

    void U4DEPAAlgorithm::removeEdgesInPolytope(U4DPolytope& uPolytope,std::vector<U4DSegment>& uEdgesList){
        
        //index to keep track of edges to be removed
        
        std::vector<int> index;
        
        //check for edges going in opposite direction
        
        for (int i=0; i<uEdgesList.size(); i++) {
            
            U4DSegment abPositiveSegment=uEdgesList.at(i);
            
            for (int j=i+1; j<=uEdgesList.size()-1; j++) {
                
                U4DSegment abNegativeSegment=uEdgesList.at(j);
                
                //if the segment has a negative segment in the edgelist, then mark it to be removed
                
                if (abPositiveSegment==abNegativeSegment.negate()) {
                    
                    index.push_back(i);
                    index.push_back(j);
                    
                }
                
            }
            
        }
        
        
        //remove edges in edgelist
    
        int removalCount=0;
        
        for (int i=0; i<index.size();i++) {
            
        
            //since edgelist will be updated with every erase, we need to make sure to keep track of the right index to remove
            uEdgesList.erase(uEdgesList.begin()+(index.at(i)-removalCount));
            
            
            removalCount++;
            
        }
        
        std::cout<<"hi";
        
    }
    
    
    void U4DEPAAlgorithm::createNewPolytopeFacesToPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint,std::vector<U4DSegment>& uEdgesList){
        
        //create new faces from the edges
        
        
        for (int i=0; i<uEdgesList.size(); i++) {
            
            //get points from edges/segments
            
            U4DPoint3n a=uEdgesList.at(i).pointA;
            U4DPoint3n b=uEdgesList.at(i).pointB;
            
            //create triangles
            U4DTriangle triangle(a,b,uPoint);
            
            //add to faces
            uPolytope.faces.push_back(triangle);
            
        }
        
        
    }
    
    
}