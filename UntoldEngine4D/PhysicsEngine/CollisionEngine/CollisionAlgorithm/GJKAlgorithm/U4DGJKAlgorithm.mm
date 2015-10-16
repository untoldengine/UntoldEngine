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
#include "U4DBoundingVolume.h"
#include "U4DDynamicModel.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    bool U4DGJKAlgorithm::collision(U4DStaticModel* uModel1, U4DStaticModel* uModel2,float dt){
        
        //clear Q
        Q.clear();
        
        U4DPoint3n closestPtToOrigin;
        U4DPoint3n originPoint(0,0,0);
        U4DPoint3n tempV; //variable to store previous value of v
        
        U4DBoundingVolume *boundingVolume1=uModel1->convexHullBoundingVolume;
        U4DBoundingVolume *boundingVolume2=uModel2->convexHullBoundingVolume;
        
        
        int iterationSteps=0; //to avoid infinite loop
        
        /*
         1. Initialize the simplex set Q to one or more points (up to d+1 points, where d is
         the dimension) from the Minkowski difference of A and B.
         */
        
        
        U4DVector3n dir(1,-1,0);
        
        U4DSimplexStruct c=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        //dir=c.minkowskiPoint.toVector();
        
        dir.negate();
        
        U4DSimplexStruct b=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        
        //test if the last point added past the origin
        if (b.minkowskiPoint.toVector().dot(dir)<0) {
            
            //if it did not passed the origin, then there is no way for the simplex to contain the point
            return false;
        }
        
        //adding simplex struct to container
        Q.push_back(c);
        Q.push_back(b);
        
        while (iterationSteps<25) {
            
            //2. Compute the point P of minimum norm in CH(Q)
            
            closestPtToOrigin=determineClosestPointOnSimplexToPoint(originPoint, Q);
            
            /*
             3. If P is the origin itself, the origin is clearly contained in the Minkowski difference
                of A and B. Stop and return A and B as intersecting.
             */
            if (closestPtToOrigin==originPoint) {
                std::cout<<Q.size()<<std::endl;
                //if intersecting, determine collision properies before returning
                return true;
            }
            
            /*
             4. Reduce Q to the smallest subset Q' of Q such that P is in CH(Q'). That is, remove
             any points from Q not determining the subsimplex of Q in which P lies.
            */
            
            determineMinimumSimplexInQ(closestPtToOrigin,Q.size());
            
            // 5. Let V=Sb(-p)-sa(p) be a supporting point in direction -P.
            
            dir=closestPtToOrigin.toVector();
            
            dir.negate();
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
        
        if (segment.isValid()) {
            
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
            
        }//end if segment is valid
        
        
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
        
        if (triangle.isValid()) {
            
            //check if the point is in the triangle
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
            
        }//end if triangle is valid
        
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
        U4DTriangle adb(a,d,b);
        U4DTriangle acd(a,c,d);
        U4DTriangle bdc(b,d,c);
        

        U4DTetrahedron tetrahedron(a,b,c,d);
        
        if (tetrahedron.isValid()) {
        
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
                }else if(adb.isPointOnTriangle(uClosestPointToOrigin)){
                    
                    
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
                }else if(bdc.isPointOnTriangle(uClosestPointToOrigin)){
                    
                    
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
            
        }//end if tetrahedron is valid
        
    }

    
    void U4DGJKAlgorithm::determineCollisionPoints(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ){
        
        U4DVector3n model1ContactPoint(0,0,0);
        
        U4DVector3n model2ContactPoint(0,0,0);
        
        U4DPoint3n origin(0,0,0);
        
        std::vector<float> barycentricCoordinates;
        
        //determine barycentric coordinates
        barycentricCoordinates=determineBarycentricCoordinatesInSimplex(origin,uQ);
        
        //aclosestpoint=sa0*u+sa1*v+sa2*w+sa3*x
        //bclosestpoint=sb0*u+sb1*v+sb2*w+sb3*x
        for (int i=0; i<uQ.size();i++) {
            
            model1ContactPoint+=uQ.at(i).sa.toVector()*barycentricCoordinates.at(i);
            
            model2ContactPoint+=uQ.at(i).sb.toVector()*barycentricCoordinates.at(i);
        }
        
        
        uModel1->collisionProperties.collisionInformation.contactPoint=model1ContactPoint;
        uModel2->collisionProperties.collisionInformation.contactPoint=model2ContactPoint;
        
    }
    
    std::vector<U4DSimplexStruct> U4DGJKAlgorithm::getCurrentSimpleStruct(){
        
        return Q;
    }
}