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
            
            int iterationSteps=0; //to avoid infinite loop
            
            //upper bound set to infinity
            float upperBound=FLT_MAX;
            U4DVector3n faceNormal(0,0,0);
            U4DVector3n penetration(0,0,0);
            
            //get bounding volume for each model
            U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
            U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
            
            U4DPoint3n origin(0.0,0.0,0.0);
            
            
            //steps
            
            //1. Build the initial polytope from the tetrahedron  produced by GJK
            U4DPolytope polytope(uQ);
            
            
            while (iterationSteps<25) {
                
                edgesList.clear();
                
                //2. Pick the closest triangle of the polytope to the origin
                U4DTriangle face=polytope.closestFaceOnPolytopeToPoint(origin);
                
                //3. Generate the next point to be included in the polytope by getting the support point in the direction of the picked
                //triangle's normal
                //faceNormal=(face.pointA-face.pointB).cross(face.pointA-face.pointC);
                faceNormal=face.closestPointOnTriangleToPoint(origin).toVector();
                
                faceNormal=faceNormal*-1.0;
                
                U4DSimplexStruct simplexPoint=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, faceNormal);
               
                penetration=simplexPoint.minkowskiPoint.toVector();
                
                
                //4. update the upperbound
                U4DVector3n normalizedFaceNormal=faceNormal;
                normalizedFaceNormal.normalize();
                
                upperBound=MIN(upperBound, penetration.dot(normalizedFaceNormal));
                
                //4. If this point is no further from the origin than the picked triangle then go to step 7.
                if (faceNormal.magnitudeSquare()>=upperBound) {
                    break;  //break from loop
                }
            
                
                //5. Remove all faces from the polytope that can be seen by this new point, this will create a hole
                // that must be filled with new faces built from the new support point in the remaining points from the old faces.
                
                removeAllFacesSeenByPoint(polytope, simplexPoint.minkowskiPoint);
                
                removeEdgesInPolytope(polytope);
                
                createNewPolytopeFacesToPoint(polytope, simplexPoint.minkowskiPoint);
                
                iterationSteps++;
                //6. Go to step 2
            }
            
            //7. Use the current closest triangle to the origin to extrapolate the contact information
            penetration.show();
        
        
        }
    }
    
    void U4DEPAAlgorithm::removeAllFacesSeenByPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint){
        
        //what faces are seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        //we need to remove all faces seen by the point
        
        for (int i=0; i<uPolytope.faces.size(); i++) {
            
            if (uPolytope.faces.at(i).directionOfTriangleNormalToPoint(uPoint)>=0) { //if dot>=0, then face seen by point, so save these edges
                
                U4DSegment ab(uPolytope.faces.at(i).pointA,uPolytope.faces.at(i).pointB);
                U4DSegment ac(uPolytope.faces.at(i).pointB,uPolytope.faces.at(i).pointC);
                U4DSegment bc(uPolytope.faces.at(i).pointC,uPolytope.faces.at(i).pointA);
                
                edgesList.push_back(ab);
                edgesList.push_back(ac);
                edgesList.push_back(bc);
                
                
            }else{ //else the face is not seen by point, so save the face
                
               facesNotSeenByPoint.push_back(uPolytope.faces.at(i));
                
            }
        }
        
        //clear faces
        uPolytope.faces.clear();
        
        //copy faces with faces not seen by point
        uPolytope.faces=facesNotSeenByPoint;
        
    }
    

    void U4DEPAAlgorithm::removeEdgesInPolytope(U4DPolytope& uPolytope){
        
        //index to keep track of edges to be removed
        
        std::vector<int> index;
        
        //check for edges going in opposite direction
        
        for (int i=0; i<edgesList.size(); i++) {
            
            U4DSegment abPositiveSegment=edgesList.at(i);
            
            for (int j=i+1; j<=edgesList.size()-1; j++) {
                
                U4DSegment abNegativeSegment=edgesList.at(j);
                
                //if the segment has a negative segment in the edgelist, then mark it to be removed
                
                if (abPositiveSegment==abNegativeSegment.negate()) {
                    
                    index.push_back(i);
                    index.push_back(j);
                    
                }
                
            }
            
        }
        
        //do a very simple sort
        std::sort(index.begin(), index.end());
        
        //remove edges in edgelist
    
        int removalCount=0;
        
        std::vector<U4DSegment>::iterator it=edgesList.begin(), end=edgesList.end();
        
        for (; it!=end;) {
            
           
        }
        
       
    }
    
    
    void U4DEPAAlgorithm::createNewPolytopeFacesToPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint){
        
        //create new faces from the edges
        
        
         for(int i=0; i<edgesList.size(); i++){
            
            //get points from edges/segments
            
            U4DPoint3n a=edgesList.at(i).pointA;
            U4DPoint3n b=edgesList.at(i).pointB;
            
            //create triangles
            U4DTriangle triangle(a,b,uPoint);
            
            //add to faces
            uPolytope.faces.push_back(triangle);
            
        }
        
        
    }
    
    
}