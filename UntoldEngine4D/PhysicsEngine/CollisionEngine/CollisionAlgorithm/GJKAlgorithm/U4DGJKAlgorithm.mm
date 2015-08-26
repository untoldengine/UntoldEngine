//
//  U4DGJKAlgorithm.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DGJKAlgorithm.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "U4DTetrahedron.h"
#include "U4DConvexPolygon.h"
#include "U4DDynamicModel.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    bool U4DGJKAlgorithm::collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){
        
        //clear Q
        Q.clear();
        
        
        U4DPoint3n closestPtToOrigin;
        U4DPoint3n originPoint(0,0,0);
        U4DPoint3n tempV; //variable to store previous value of v
        
        U4DConvexPolygon *boundingVolume1=uModel1->narrowPhaseBoundingVolume;
        U4DConvexPolygon *boundingVolume2=uModel2->narrowPhaseBoundingVolume;
        
        
        int iterationSteps=0; //to avoid infinite loop
        
        /*
         1. Initialize the simplex set Q to one or more points (up to d+1 points, where d is
         the dimension) from the Minkowski difference of A and B.
         */
        
        
        U4DVector3n dir(1,1,1);
       
        U4DSimplexStruct c=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        dir=c.minkowskiPoint.toVector();
        dir.negate();
        
        U4DSimplexStruct b=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        if (b.minkowskiPoint.toVector().dot(dir)<0) {
            return false;
        }
        
        //adding simplex struct to container
        Q.push_back(c);
        Q.push_back(b);
        
        while (iterationSteps<25) {
            
            //2. Compute the point P of minimum norm in CH(Q)
            
            closestPtToOrigin=determineClosestPointOnSimplexToPoint(originPoint, Q.size());
            
            /*
             3. If P is the origin itself, the origin is clearly contained in the Minkowski difference
                of A and B. Stop and return A and B as intersecting.
             */
            if (closestPtToOrigin==originPoint) {
                
                //if intersecting, determine collision properies before returning
                
                determineCollisionPoints(uModel1, uModel2);
                
                return true;
            }
            
            /*
             4. Reduce Q to the smallest subset Q' of Q such that P is in CH(Q'). That is, remove
             any points from Q not determining the subsimplex of Q in which P lies.
            */
            
            determineMinimumSimplexInQ(closestPtToOrigin,Q.size());
            
            // 5. Let V=Sb(-p)-sa(p) be a supporting point in direction -P.
            
            dir=closestPtToOrigin.toVector();
            
            U4DSimplexStruct v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
            
            /*
             6. If V is no more extremal in direction -P than P itself, stop and return A and B as not
             intersecting. The length of the vector from the origin to P is the separation distance of
             A and B.
             */
            
                if (v.minkowskiPoint.toVector().dot(dir)<0.0 || v.minkowskiPoint==tempV) {
        
                    return false;
                }
            
            /*
             7. Add V to Q and got to step 2.
             */
            
            tempV=v.minkowskiPoint;
            
            Q.push_back(v);
            
            iterationSteps++;
        }
        
        return false;
    }

    void U4DGJKAlgorithm::determineCollisionPoints(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2){
        
        U4DVector3n model1ContactPoint(0,0,0);
        
        U4DVector3n model2ContactPoint(0,0,0);
        
        U4DPoint3n origin(0,0,0);
        
        std::vector<float> barycentricCoordinates;
        
        //determine barycentric coordinates
        barycentricCoordinates=determineBarycentricCoordinatesInSimplex(origin, Q.size());
        
        //aclosestpoint=sa0*u+sa1*v+sa2*w+sa3*x
        //bclosestpoint=sb0*u+sb1*v+sb2*w+sb3*x
        for (int i=0; i<Q.size();i++) {
            
            model1ContactPoint+=Q.at(i).sa.toVector()*barycentricCoordinates.at(i);
            
            model2ContactPoint+=Q.at(i).sb.toVector()*barycentricCoordinates.at(i);
        }
        
        
        uModel1->collisionProperties.collisionInformation.contactPoint=model1ContactPoint;
        uModel2->collisionProperties.collisionInformation.contactPoint=model2ContactPoint;
    
    }
    

    U4DSimplexStruct U4DGJKAlgorithm::calculateSupportPointInDirection(U4DConvexPolygon *uBoundingVolume1, U4DConvexPolygon* uBoundingVolume2, U4DVector3n& uDirection){
        
        //V=Sb(-p)-sa(p)
        
        U4DPoint3n sa=uBoundingVolume1->getSupportPointInDirection(uDirection);
        
        uDirection.negate();
        
        U4DPoint3n sb=uBoundingVolume2->getSupportPointInDirection(uDirection);
        
        //sb - sa
        U4DPoint3n sab=(sa-sb).toPoint();
        
        U4DSimplexStruct supportPoint;
        
        supportPoint.sa=sa;
        supportPoint.sb=sb;
        supportPoint.minkowskiPoint=sab;
        
        return supportPoint;
        
    }

    void U4DGJKAlgorithm::determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer){
        
        if (uNumberOfSimplexInContainer==2) {
            
            //do line 
            determineLinearCombinationOfPtInLine(uClosestPointToOrigin);
            
        }else if(uNumberOfSimplexInContainer==3){
            //do triangle
            determineLinearCombinationOfPtInTriangle(uClosestPointToOrigin);
            
        }else if(uNumberOfSimplexInContainer==4){
            //do tetrahedron
            determineLinearCombinationOfPtInTetrahedron(uClosestPointToOrigin);
        }
        
    }
        
    void U4DGJKAlgorithm::determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin){
        
        U4DSimplexStruct tempSupportPointQA=Q.at(0);
        U4DSimplexStruct tempSupportPointQB=Q.at(1);
        
        U4DPoint3n a=Q.at(0).minkowskiPoint;
        U4DPoint3n b=Q.at(1).minkowskiPoint;
        
        U4DSegment segment(a,b);
        
        Q.clear();
        
        //check if point is equals to a
        if (a==uClosestPointToOrigin) {
            Q.push_back(tempSupportPointQA);
        
        //check if point is equals to b
        }else if(b==uClosestPointToOrigin){
            Q.push_back(tempSupportPointQB);
            
        //else point lies in segment ab
        }else{
            
            Q.push_back(tempSupportPointQA);
            Q.push_back(tempSupportPointQB);
        }
        
    }

    void U4DGJKAlgorithm::determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin){
        
        U4DSimplexStruct tempSupportPointQA=Q.at(0);
        U4DSimplexStruct tempSupportPointQB=Q.at(1);
        U4DSimplexStruct tempSupportPointQC=Q.at(2);
        
        
        U4DPoint3n a=Q.at(0).minkowskiPoint;
        U4DPoint3n b=Q.at(1).minkowskiPoint;
        U4DPoint3n c=Q.at(2).minkowskiPoint;
        
        U4DSegment ac(a,c);
        U4DSegment bc(b,c);
        U4DSegment ab(a,b);
        

        U4DTriangle triangle(a,b,c);
        
        //check if the point is in the triangl
        if (triangle.isPointOnTriangle(uClosestPointToOrigin)) {
         
            //clear Q
            Q.clear();
            
            
            //if point is a linear combination of ab
            if(ab.isPointOnSegment(uClosestPointToOrigin)){
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQB);
                
            //if point is a linear combination of ac
            }else if(ac.isPointOnSegment(uClosestPointToOrigin)){
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQC);
                
            //if point is a linear combination of bc
            }else if(bc.isPointOnSegment(uClosestPointToOrigin)){
                
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
                
            //the point is part of the triangle but not found on edges.
            }else{
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
                
            }
            
        }
        
    }

    void U4DGJKAlgorithm::determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin){
        
        
        U4DSimplexStruct tempSupportPointQA=Q.at(0);
        U4DSimplexStruct tempSupportPointQB=Q.at(1);
        U4DSimplexStruct tempSupportPointQC=Q.at(2);
        U4DSimplexStruct tempSupportPointQD=Q.at(3);
        
        U4DPoint3n a=Q.at(0).minkowskiPoint;
        U4DPoint3n b=Q.at(1).minkowskiPoint;
        U4DPoint3n c=Q.at(2).minkowskiPoint;
        U4DPoint3n d=Q.at(3).minkowskiPoint;
        
        U4DTriangle abc(a,b,c);
        U4DTriangle abd(a,b,d);
        U4DTriangle acd(a,c,d);
        U4DTriangle bcd(b,c,d);
        

        U4DTetrahedron tetrahedron(a,b,c,d);
        
        //check if the point is in the tetrahedron
        
        if (tetrahedron.isPointInTetrahedron(uClosestPointToOrigin)) {
            
            //clear Q
            Q.clear();
            
                    //if point is a linear combination of abc
            if(abc.isPointOnTriangle(uClosestPointToOrigin)){
                
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
            
                
            determineMinimumSimplexInQ(uClosestPointToOrigin,Q.size());
            //if point is a linear combination of abd
            }else if(abd.isPointOnTriangle(uClosestPointToOrigin)){
                
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
            
            determineMinimumSimplexInQ(uClosestPointToOrigin,Q.size());
            //if point is a linear combination of acd
            }else if(acd.isPointOnTriangle(uClosestPointToOrigin)){
                
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQC);
                Q.push_back(tempSupportPointQD);
               
            determineMinimumSimplexInQ(uClosestPointToOrigin,Q.size());
            //if point is a linear combination of bcd
            }else if(bcd.isPointOnTriangle(uClosestPointToOrigin)){
                
                
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
                Q.push_back(tempSupportPointQD);
                
            determineMinimumSimplexInQ(uClosestPointToOrigin,Q.size());
            //point is found in tetrahedron but not found on the triangle faces
            }else{
                
                Q.push_back(tempSupportPointQA);
                Q.push_back(tempSupportPointQB);
                Q.push_back(tempSupportPointQC);
                Q.push_back(tempSupportPointQD);
                
            }
            
        }
        
    }

    U4DPoint3n U4DGJKAlgorithm::determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,int uNumberOfSimplexInContainer){
        
        U4DPoint3n closestPoint;
        
        if (uNumberOfSimplexInContainer==2) {
            //do line
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            
            U4DSegment segment(a,b);
            
            closestPoint=segment.closestPointOnSegmentToPoint(uPoint);
        
        }else if(uNumberOfSimplexInContainer==3){
            //do triangle
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            U4DPoint3n c=Q.at(2).minkowskiPoint;
            
            U4DTriangle triangle(a,b,c);
            
            closestPoint=triangle.closestPointOnTriangleToPoint(uPoint);
            
            
        }else if(uNumberOfSimplexInContainer==4){
            //do tetrahedron
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            U4DPoint3n c=Q.at(2).minkowskiPoint;
            U4DPoint3n d=Q.at(3).minkowskiPoint;
            
            U4DTetrahedron tetrahedron(a,b,c,d);
         
            closestPoint=tetrahedron.closestPointOnTetrahedronToPoint(uPoint);
            
        }
        
        return closestPoint;
    }
    
    std::vector<float> U4DGJKAlgorithm::determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin, int uNumberOfSimplexInContainer){
        
        std::vector<float> barycentricCoordinates;
        
        if (uNumberOfSimplexInContainer==2) {
            
            //do line
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            
            U4DSegment segment(a,b);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            
            segment.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            
            
            
        }else if(uNumberOfSimplexInContainer==3){
            
            //do triangle
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            U4DPoint3n c=Q.at(2).minkowskiPoint;
            
            U4DTriangle triangle(a,b,c);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            float uBarycentricW=0.0;
            
            triangle.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV, uBarycentricW);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            barycentricCoordinates.push_back(uBarycentricW);
        
            
            
        }else if(uNumberOfSimplexInContainer==4){
            
            //do tetrahedron
            U4DPoint3n a=Q.at(0).minkowskiPoint;
            U4DPoint3n b=Q.at(1).minkowskiPoint;
            U4DPoint3n c=Q.at(2).minkowskiPoint;
            U4DPoint3n d=Q.at(3).minkowskiPoint;
            
            U4DTetrahedron tetrahedron(a,b,c,d);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            float uBarycentricW=0.0;
            float uBarycentricX=0.0;
            
            tetrahedron.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV, uBarycentricW, uBarycentricX);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            barycentricCoordinates.push_back(uBarycentricW);
            barycentricCoordinates.push_back(uBarycentricX);
            
        }
        
        return barycentricCoordinates;
        
    }
    
}