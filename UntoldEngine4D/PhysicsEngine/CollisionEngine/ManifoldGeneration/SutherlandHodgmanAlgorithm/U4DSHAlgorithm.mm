//
//  U4DSHAlgorithm.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/18/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DSHAlgorithm.h"
#include "U4DPlane.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "Constants.h"

namespace U4DEngine {

    U4DSHAlgorithm::U4DSHAlgorithm(){
        
    }
    
    U4DSHAlgorithm::~U4DSHAlgorithm(){
        
    }
    
    void U4DSHAlgorithm::determineContactManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ,U4DPoint3n& uClosestPoint){
        
        //step 1. Create plane
        U4DVector3n collisionNormalOfModel1=uModel1->getCollisionNormalFaceDirection();
        U4DPlane planeCollisionOfModel1(collisionNormalOfModel1,uClosestPoint);
        
        U4DVector3n collisionNormalOfModel2=uModel2->getCollisionNormalFaceDirection();
        U4DPlane planeCollisionOfModel2(collisionNormalOfModel2,uClosestPoint);
        
        //step 2. For each model determine which face is most parallel to plane, i.e., dot product ~0
        
        std::vector<MODELFACES> parallelFacesModel1=mostParallelFacesToPlane(uModel1, planeCollisionOfModel1);
        
        std::vector<MODELFACES> parallelFacesModel2=mostParallelFacesToPlane(uModel2, planeCollisionOfModel2);
        
        //step 3. for each model project selected faces onto plane
        
        std::vector<U4DTriangle> projectedFacesModel1=projectFacesToPlane(parallelFacesModel1, planeCollisionOfModel1);
        
        std::vector<U4DTriangle> projectedFacesModel2=projectFacesToPlane(parallelFacesModel2, planeCollisionOfModel2);
        
        //step 4. Break triangle into segments and remove any duplicate segments
        std::vector<U4DSegment> polygonEdgesOfModel1=getEdgesFromFaces(projectedFacesModel1);
        std::vector<U4DSegment> polygonEdgesOfModel2=getEdgesFromFaces(projectedFacesModel2);
        
        //step 5. perform sutherland
        
        std::cout<<"stop"<<std::endl;
        
    }
    
    std::vector<MODELFACES> U4DSHAlgorithm::mostParallelFacesToPlane(U4DDynamicModel* uModel, U4DPlane& uPlane){
        
        std::vector<MODELFACES> modelFaces; //faces of each polygon in the model
        
        float parallelToPlane=-FLT_MIN;
        float support=0.0;
        
        U4DVector3n planeNormal=uPlane.n;
        
        //Normalize the plane so the dot product between the face normal and the plane falls within [-1,1]
        planeNormal.normalize();
        
        for(auto n: uModel->bodyCoordinates.getFacesDataFromContainer()){
            
            //update all faces with current model position
            
            U4DVector3n vertexA=n.pointA.toVector();
            U4DVector3n vertexB=n.pointB.toVector();
            U4DVector3n vertexC=n.pointC.toVector();
            
            vertexA=uModel->getAbsoluteMatrixOrientation()*vertexA;
            vertexA=vertexA+uModel->getAbsolutePosition();
            
            vertexB=uModel->getAbsoluteMatrixOrientation()*vertexB;
            vertexB=vertexB+uModel->getAbsolutePosition();
            
            vertexC=uModel->getAbsoluteMatrixOrientation()*vertexC;
            vertexC=vertexC+uModel->getAbsolutePosition();
            
            n.pointA=vertexA.toPoint();
            n.pointB=vertexB.toPoint();
            n.pointC=vertexC.toPoint();
            
            //structure to store all faces
            MODELFACES modelFace;
            
            //store triangle
            modelFace.triangle=n;
            
            //get the normal for the face & normalize
            U4DVector3n faceNormal=n.getTriangleNormal();
            
            //Normalize the face normal vector so the dot product between the face normal and the plane falls within [-1,1]
            faceNormal.normalize();
            
            
            //get the minimal dot product
            support=faceNormal.dot(planeNormal);
            
            
            modelFace.dotProduct=support;
            
            modelFaces.push_back(modelFace);
            
            //parallelToPlane keeps track of the most parallel dot product between the triangle normal vector and the plane normal
            
            if(support>parallelToPlane){
                
                parallelToPlane=support;
                
            }
            
        }

    
        //remove all faces with dot product not equal to most parallel face to plane
        modelFaces.erase(std::remove_if(modelFaces.begin(), modelFaces.end(),[parallelToPlane](MODELFACES &e){ return !(fabs(e.dotProduct - parallelToPlane) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(e.dotProduct, parallelToPlane)));} ),modelFaces.end());
        
        return modelFaces;
        
    }
    
    std::vector<U4DTriangle> U4DSHAlgorithm::projectFacesToPlane(std::vector<MODELFACES>& uFaces, U4DPlane& uPlane){
        
        std::vector<U4DTriangle> projectedTriangles;
        
        for(auto n:uFaces){
           
            U4DTriangle triangle=n.triangle.projectTriangleOntoPlane(uPlane);
            
            projectedTriangles.push_back(triangle);
        }
        
        return projectedTriangles;
    }
    
    std::vector<U4DSegment> U4DSHAlgorithm::getEdgesFromFaces(std::vector<U4DTriangle>& uFaces){
        
        std::vector<MODELEDGES> modelEdges;
        std::vector<U4DSegment> polygonEdges;
    
        for(auto n:uFaces){
            
            std::vector<U4DSegment> segment=n.getSegments();
            
            MODELEDGES modelEdgeAB;
            MODELEDGES modelEdgeBC;
            MODELEDGES modelEdgeCA;
            
            modelEdgeAB.segment=segment.at(0);
            modelEdgeBC.segment=segment.at(1);
            modelEdgeCA.segment=segment.at(2);
            
            modelEdgeAB.isDuplicate=false;
            modelEdgeBC.isDuplicate=false;
            modelEdgeCA.isDuplicate=false;
            
            std::vector<MODELEDGES> tempEdges{modelEdgeAB,modelEdgeBC,modelEdgeCA};
            
            if (modelEdges.size()==0) {
                
                modelEdges=tempEdges;
                
            }else{
             
                for(auto& edge:modelEdges){
                    
                    for(auto& tempEdge:tempEdges){
                        
                        //check if there are duplicate edges
                        if (edge.segment==tempEdge.segment || edge.segment==tempEdge.segment.negate()) {
                            
                            edge.isDuplicate=true;
                            tempEdge.isDuplicate=true;
                            
                        }
                        
                    }
                }
                
                modelEdges.push_back(tempEdges.at(0));
                modelEdges.push_back(tempEdges.at(1));
                modelEdges.push_back(tempEdges.at(2));
                
            }
            
        }
        
        //remove all duplicate faces
        modelEdges.erase(std::remove_if(modelEdges.begin(), modelEdges.end(),[](MODELEDGES &e){ return e.isDuplicate;} ),modelEdges.end());
        
        
        for(auto n:modelEdges){
            
            polygonEdges.push_back(n.segment);
        }
        
        return polygonEdges;
        
    }

    std::vector<U4DSegment> U4DSHAlgorithm::clipPolygons(std::vector<U4DSegment> uEdges1, std::vector<U4DSegment> uEdges2){
        
        
    }
    
    
    
}


