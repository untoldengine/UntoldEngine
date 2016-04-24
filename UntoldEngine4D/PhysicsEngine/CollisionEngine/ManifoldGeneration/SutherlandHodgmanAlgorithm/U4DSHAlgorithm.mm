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
        
        std::vector<CONTACTFACES> parallelFacesModel1=mostParallelFacesToPlane(uModel1, planeCollisionOfModel1);
        
        std::vector<CONTACTFACES> parallelFacesModel2=mostParallelFacesToPlane(uModel2, planeCollisionOfModel2);
        
        //step 3. for each model project selected faces onto plane
        
        std::vector<U4DTriangle> projectedFacesModel1=projectFacesToPlane(parallelFacesModel1, planeCollisionOfModel1);
        
        std::vector<U4DTriangle> projectedFacesModel2=projectFacesToPlane(parallelFacesModel2, planeCollisionOfModel2);
        
        //step 4. Break triangle into segments and remove any duplicate segments
        std::vector<CONTACTEDGE> polygonEdgesOfModel1=getEdgesFromFaces(projectedFacesModel1,planeCollisionOfModel1);
        std::vector<CONTACTEDGE> polygonEdgesOfModel2=getEdgesFromFaces(projectedFacesModel2,planeCollisionOfModel2);
        
        //step 5. Determine reference polygon

        float maxFaceParallelToPlaneInModel1=-FLT_MIN;
        float maxFaceParallelToPlaneInModel2=-FLT_MIN;
        
        //Get the most dot product parallel to plane for each model
        for(auto n:parallelFacesModel1){
            
            maxFaceParallelToPlaneInModel1=MAX(n.dotProduct,maxFaceParallelToPlaneInModel1);
            
        }
        
        for(auto n:parallelFacesModel2){
            
            maxFaceParallelToPlaneInModel2=MAX(n.dotProduct,maxFaceParallelToPlaneInModel2);
            
        }
        
        //compare dot product and assign a reference plane
        
        //step 5. perform sutherland
        
        if (maxFaceParallelToPlaneInModel1>=maxFaceParallelToPlaneInModel2) {
            
            //set polygon in model 1 as the reference plane
            //and polygon in model 2 as the incident plane
            
            clipPolygons(polygonEdgesOfModel1, polygonEdgesOfModel2);
            
        }else{
            
            //set polygon in model 2 as the reference plane
            //and polygon in model 1 as the incident plane
            
            clipPolygons(polygonEdgesOfModel2, polygonEdgesOfModel1);
        }
        
        
        
        std::cout<<"stop"<<std::endl;
        
    }
    
    std::vector<CONTACTFACES> U4DSHAlgorithm::mostParallelFacesToPlane(U4DDynamicModel* uModel, U4DPlane& uPlane){
        
        std::vector<CONTACTFACES> modelFaces; //faces of each polygon in the model
        
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
            CONTACTFACES modelFace;
            
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
        modelFaces.erase(std::remove_if(modelFaces.begin(), modelFaces.end(),[parallelToPlane](CONTACTFACES &e){ return !(fabs(e.dotProduct - parallelToPlane) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(e.dotProduct, parallelToPlane)));} ),modelFaces.end());
        
        
        return modelFaces;
        
    }
    
    std::vector<U4DTriangle> U4DSHAlgorithm::projectFacesToPlane(std::vector<CONTACTFACES>& uFaces, U4DPlane& uPlane){
        
        std::vector<U4DTriangle> projectedTriangles;
        
        for(auto n:uFaces){
           
            U4DTriangle triangle=n.triangle.projectTriangleOntoPlane(uPlane);
            
            projectedTriangles.push_back(triangle);
        }
        
        return projectedTriangles;
    }
    
    std::vector<CONTACTEDGE> U4DSHAlgorithm::getEdgesFromFaces(std::vector<U4DTriangle>& uFaces, U4DPlane& uPlane){
        
        std::vector<CONTACTEDGE> modelEdges;
    
        //For each face, get its corresponding edges
        
        for(auto n:uFaces){
            
            std::vector<U4DSegment> segment=n.getSegments();
            
            CONTACTEDGE modelEdgeAB;
            CONTACTEDGE modelEdgeBC;
            CONTACTEDGE modelEdgeCA;
            
            modelEdgeAB.segment=segment.at(0);
            modelEdgeBC.segment=segment.at(1);
            modelEdgeCA.segment=segment.at(2);
            
            modelEdgeAB.isDuplicate=false;
            modelEdgeBC.isDuplicate=false;
            modelEdgeCA.isDuplicate=false;
            
            std::vector<CONTACTEDGE> tempEdges{modelEdgeAB,modelEdgeBC,modelEdgeCA};
            
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
        modelEdges.erase(std::remove_if(modelEdges.begin(), modelEdges.end(),[](CONTACTEDGE &e){ return e.isDuplicate;} ),modelEdges.end());
        
        //calculate the normal of the line by doing a cross product between the plane normal and the segment direction
        for(auto& n:modelEdges){
            
            std::vector<U4DPoint3n> points=n.segment.getPoints();
            
            //get points
            U4DPoint3n pointA=points.at(0);
            U4DPoint3n pointB=points.at(1);
            
            //compute line
            U4DVector3n line=pointB-pointA;
            
            //get normal
            U4DVector3n normal=uPlane.n.cross(line);
            
            //assign normal to model edge
            n.normal=normal;
            
        }
        
        return modelEdges;
        
    }
    

    std::vector<U4DSegment> U4DSHAlgorithm::clipPolygons(std::vector<CONTACTEDGE>& uReferencePolygons, std::vector<CONTACTEDGE>& uIncidentPolygons){
        
        std::vector<U4DSegment> clipEdges;
        std::vector<U4DSegment> tempClipEdges;
        
        //copy the incident edges into the the clip edges
        for(auto n:uIncidentPolygons){
            
            clipEdges.push_back(n.segment);
            
        }
    
        
        for(auto referencePolygon:uReferencePolygons){
            
            //clear temp edges
            tempClipEdges.clear();
            
            U4DVector3n normal=referencePolygon.normal;
            U4DPoint3n pointOnPlane=referencePolygon.segment.pointA;
            
            //create plane
            U4DPlane referencePlane(normal,pointOnPlane);
            
            //For every segment determine the location of each point and the direction of the segment
            for(auto incidentEdges:clipEdges){
                
                //get the points in the segment
                std::vector<U4DPoint3n> incidentPoints=incidentEdges.getPoints();
                std::vector<POINTINFORMATION> pointInformation;
                
                //determine the location of each point segment with respect to the plane normal
                for(int i=0; i<incidentPoints.size(); i++){
                    
                    float direction=referencePlane.magnitudeSquareOfPointToPlane(incidentPoints.at(i));
                    
                    pointInformation.at(i).point=incidentPoints.at(i);
                    
                    if (direction>U4DEngine::zeroEpsilon) {
                        
                        pointInformation.at(i).location=insidePlane;
                    
                    }else{
                       
                        if (direction<U4DEngine::zeroEpsilon) {
                            
                            pointInformation.at(i).location=outsidePlane;
                        
                        }else{
                           
                            pointInformation.at(i).location=boundaryPlane;
                        
                        }
                        
                    }
                
                }//end for
                    
                //determine the direction of the segment
                CONTACTEDGEINFORMATION edgeInformation;
                edgeInformation.contactSegment=incidentEdges;
                
                //segment going from INSIDE of plane to OUTSIDE of plane
                if (pointInformation.at(0).location==insidePlane && pointInformation.at(1).location==outsidePlane) {
                    
                    edgeInformation.direction=inToOut;
                    
                //segment going from OUTSIDE of plane to INSIDE of plane
                }else if (pointInformation.at(0).location==outsidePlane && pointInformation.at(1).location==insidePlane){
                    
                    edgeInformation.direction=outToIn;
                    
                //segment going from INSIDE of plane to INSIDE of plane
                }else if (pointInformation.at(0).location==insidePlane && pointInformation.at(1).location==insidePlane){
                
                    edgeInformation.direction=inToIn;
                    
                //segment going from OUTSIDE of plane to OUTSIDE of plane
                }else if (pointInformation.at(0).location==outsidePlane && pointInformation.at(1).location==outsidePlane){
                    
                    edgeInformation.direction=outToOut;
                    
                //segment is in boundary
                }else{
                    
                    edgeInformation.direction=inBoundary;
                    
                }
                
                
                //clip the segment
                std::vector<U4DPoint3n> clippedPoints;
                
                if (edgeInformation.direction==inToOut) {
                    //Add intersection point
                    U4DPoint3n intersectPoint;
                    
                    referencePlane.intersectSegment(incidentEdges, intersectPoint);
                    
                    clippedPoints.push_back(intersectPoint);
                    
                }else if (edgeInformation.direction==outToIn){
                    //Add intersection point and pointB
                    
                    
                }else if (edgeInformation.direction==inToIn){
                    //Add pointB
                    
                }else if (edgeInformation.direction==outToOut){
                    //Add none
                    
                }else{
                    //edge is a boundary
                    //Add pointA and PointB
                }
                    
                    
                
                
                
                
            }//end for
            
        }//end for
        
    }
    
    
    
}


