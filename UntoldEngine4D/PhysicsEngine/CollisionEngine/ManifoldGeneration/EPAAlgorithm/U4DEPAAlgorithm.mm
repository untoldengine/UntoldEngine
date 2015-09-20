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
            
        }
    }
    
    void U4DEPAAlgorithm::removeAllFacesSeenByPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint, std::vector<Edges>& uRemovedFaceSavedEdges){
        
        //what faces are not seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        //we need to remove all faces seen by the point
        
        for (int i=0; i<uPolytope.faces.size(); i++) {
            
            U4DTriangle triangle=uPolytope.faces.at(i);
            
            U4DVector3n triangleNormal=(triangle.pointA-triangle.pointB).cross(triangle.pointA-triangle.pointC);
            
            if (triangleNormal.dot(triangle.pointA-uPoint)>=0) { //if dot>0, then face seen by point, so save these edges
                
                U4DSegment ab(uPolytope.faces.at(i).pointA,uPolytope.faces.at(i).pointB);
                U4DSegment bc(uPolytope.faces.at(i).pointB,uPolytope.faces.at(i).pointC);
                U4DSegment ca(uPolytope.faces.at(i).pointC,uPolytope.faces.at(i).pointA);
                
                Edges edgeAB,edgeBC,edgeCA;
                
                edgeAB.edge=ab;
                edgeAB.tag=false;
                
                edgeBC.edge=bc;
                edgeBC.tag=false;
                
                edgeCA.edge=ca;
                edgeCA.tag=false;
                
                std::vector<Edges> removedFaceThreeEdges{edgeAB,edgeBC,edgeCA};
                
                if (uRemovedFaceSavedEdges.size()==0) {
                    
                    //container is empty, no need to test
                    uRemovedFaceSavedEdges.push_back(edgeAB);
                    uRemovedFaceSavedEdges.push_back(edgeBC);
                    uRemovedFaceSavedEdges.push_back(edgeCA);
                    
                    
                }else{
                    
                    for (int j=0; j<removedFaceThreeEdges.size(); j++) {
                        
                        U4DSegment negateEdge=removedFaceThreeEdges.at(j).edge.negate();
                        
                        for (int z=0; z<uRemovedFaceSavedEdges.size(); z++) {
                            
                            U4DSegment edge=uRemovedFaceSavedEdges.at(z).edge;
                            
                            if (edge==negateEdge) {
                                
                                //there is a edge going in opposite direction
                                
                                //set both edges tag to true, indicating that there is a negative direction edge
                                
                                
                                removedFaceThreeEdges.at(j).tag=true;
                                uRemovedFaceSavedEdges.at(z).tag=true;
                                
                                
                            }
                            
                        }
                    }
                    
                    //add edges to container
                    uRemovedFaceSavedEdges.push_back(removedFaceThreeEdges.at(0));
                    uRemovedFaceSavedEdges.push_back(removedFaceThreeEdges.at(1));
                    uRemovedFaceSavedEdges.push_back(removedFaceThreeEdges.at(2));
                    
                }
                
                
                
            }else{ //else the face is not seen by point, so save the face
                
               facesNotSeenByPoint.push_back(uPolytope.faces.at(i));
                
            }
        }
        
        //clear faces
        uPolytope.faces.clear();
        
        //copy faces with faces not seen by point
        uPolytope.faces=facesNotSeenByPoint;
       
    }
    

    void U4DEPAAlgorithm::removeEdgesInPolytope(U4DPolytope& uPolytope, std::vector<Edges>& uRemovedFaceSavedEdges, std::vector<U4DSegment>& uEdgeList){
        
        for (int i=0; i<uRemovedFaceSavedEdges.size(); i++) {
            
            if (uRemovedFaceSavedEdges.at(i).tag==false) {
                
                uEdgeList.push_back(uRemovedFaceSavedEdges.at(i).edge);
            }
        }
        
        
    }
    
    
    void U4DEPAAlgorithm::createNewPolytopeFacesToPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint, std::vector<U4DSegment>& uEdgeList){
        
        //create new faces from the edges
        
        
         for(int i=0; i<uEdgeList.size(); i++){
            
            //get points from edges/segments
            
            U4DPoint3n a=uEdgeList.at(i).pointA;
            U4DPoint3n b=uEdgeList.at(i).pointB;
            
            //create triangles
            U4DTriangle triangle(a,b,uPoint);
            
            //add to faces
            uPolytope.faces.push_back(triangle);
            
        }
        
    }
    
}