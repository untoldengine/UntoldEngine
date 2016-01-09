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
#include "U4DStaticModel.h"


namespace U4DEngine {
    
    
    bool U4DGJKAlgorithm::collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){
        
        //version 3 of the GJK-TOI implementation
        
        //clear Q
        Q.clear();
        
        U4DPoint3n originPoint(0,0,0);
        U4DPoint3n tempV(0,0,0); //variable to store previous value of v
        std::vector<float> barycentricPoints; //barycentric points
        float t=0; //time of impact
        U4DVector3n s(0,0,0); //hit spot
        U4DVector3n r(0,0,0); //ray
        
        U4DBoundingVolume *boundingVolume1=uModel1->getBoundingVolume();
        U4DBoundingVolume *boundingVolume2=uModel2->getBoundingVolume();
        
        r=(uModel1->getVelocity()-uModel2->getVelocity());
        
        r.normalize();
        
        U4DVector3n dir(1,1,1);
        
        U4DSimplexStruct v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        Q.push_back(v);

        float iterations=0;
   
        while (v.minkowskiPoint.magnitudeSquare()>U4DEngine::collisionEpsilon) {
            
            
            if (iterations>10) { //iterations to avoid infinite loop
                
                return false;
            }
            
            dir=v.minkowskiPoint.toVector();
            
            dir.negate();
            
            U4DSimplexStruct p=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
            
            
            if (v.minkowskiPoint.toVector().dot(p.minkowskiPoint.toVector())>(v.minkowskiPoint.toVector().dot(r))*t) {
                
                
                if (v.minkowskiPoint.toVector().dot(r)>0.0) {
                    
                    t=v.minkowskiPoint.toVector().dot(p.minkowskiPoint.toVector())/v.minkowskiPoint.toVector().dot(r);
                    
                    if (t>1.0) {
                        
                        return false;
                    }

                    
                    s=r*t;
                    
                    closestPointToOrigin=v.minkowskiPoint;
                    
                    contactNormal=v.minkowskiPoint.toVector();
                    
                    Q.clear();
                    
                    dir=p.minkowskiPoint.toVector();
                    
                    dir.negate();
                    
                    v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
                    
                    Q.push_back(v);
                    
                    
                }else{
                    
                    return false;
                }
            }
            
            p.minkowskiPoint=(s.toPoint()-p.minkowskiPoint).toPoint();
            
            Q.push_back(p);
            
            v.minkowskiPoint=determineClosestPointOnSimplexToPoint(originPoint, Q);
            
            determineMinimumSimplexInQ(v.minkowskiPoint,Q.size());
            
            iterations++;
            
        }
  
        
        //set time of impact for each model.
        
        if (t>U4DEngine::collisionEpsilon&&t<minimumTimeOfImpact) {
            
            //minimum time step allowed
            uModel1->setTimeOfImpact(minimumTimeOfImpact);
            uModel2->setTimeOfImpact(minimumTimeOfImpact);
            
        }else{
            
            uModel1->setTimeOfImpact(t);
            uModel2->setTimeOfImpact(t);
            
        }
                
        //if the simplex container is 2, it is not enough to get the correct normal data. 
        
        if (Q.size()<=2) {
            return false;
        }
        
        if (t<U4DEngine::collisionEpsilon) {
           
            //Set contact normal
            contactNormal.normalize();
            
            uModel1->setCollisionNormalDirection(contactNormal);
            
            U4DVector3n negateContactNormal=contactNormal*-1.0;
            
            uModel2->setCollisionNormalDirection(negateContactNormal);
            
            //reset time of impact
            uModel1->resetTimeOfImpact();
            
            uModel2->resetTimeOfImpact();
            
            return true;
        }
        

       return false;
        
        
        //Version 2 of the GJK
        
        //clear Q
//        Q.clear();
//        
//        U4DPoint3n closestPtToOrigin(0,0,0);
//        U4DPoint3n originPoint(0,0,0);
//        U4DPoint3n tempV(0,0,0); //variable to store previous value of v
//        std::vector<float> barycentricPoints; //barycentric points
//        
//        //GJK continuous collision variables
//       
//        U4DBoundingVolume *boundingVolume1=uModel1->getBoundingVolume();
//        U4DBoundingVolume *boundingVolume2=uModel2->getBoundingVolume();
//
//        /*
//         1. Initialize the simplex set Q to one or more points (up to d+1 points, where d is
//         the dimension) from the Minkowski difference of A and B.
//         */
//        
//
//        U4DVector3n dir(1,1,1);
//
//        U4DSimplexStruct v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//
//        Q.push_back(v);
//        
//        dir=v.minkowskiPoint.toVector();
//        
//        dir.negate();
//        
//        U4DSimplexStruct w=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//        
//        float iterations=0;
//        //Algorithm found in Game Physics Pearls. Page 106
//        while (v.minkowskiPoint.magnitudeSquare()-v.minkowskiPoint.toVector().dot(w.minkowskiPoint.toVector())>U4DEngine::epsilon) {
//            
//            if (iterations>10) {
//                return false;
//            }
//            
//            Q.push_back(w);
//            
//            v.minkowskiPoint=determineClosestPointOnSimplexToPoint(originPoint, Q);
//            
//            
//            
//            determineMinimumSimplexInQ(v.minkowskiPoint,Q.size());
//            
//            dir=v.minkowskiPoint.toVector();
//            
//            dir.negate();
//            
//            w=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//            
//            iterations++;
//        }
//        
//        float distance=v.minkowskiPoint.magnitudeSquare();
//        closestPointToOrigin=v.minkowskiPoint;
//        
//        if (distance>U4DEngine::epsilon) {
//            return false;
//        }
//        
//        return true;
        
        
        
        
        //Version 1 of the GJK
       
        
        //clear Q
//        Q.clear();
//        
//        U4DPoint3n closestPtToOrigin(0,0,0);
//        U4DPoint3n originPoint(0,0,0);
//        U4DPoint3n tempV(0,0,0); //variable to store previous value of v
//        std::vector<float> barycentricPoints; //barycentric points
//        
//        U4DBoundingVolume *boundingVolume1=uModel1->getBoundingVolume();
//        U4DBoundingVolume *boundingVolume2=uModel2->getBoundingVolume();
//        
//        int iterationSteps=0; //to avoid infinite loop
//        
//        /*
//         1. Initialize the simplex set Q to one or more points (up to d+1 points, where d is
//         the dimension) from the Minkowski difference of A and B.
//         */
//        
//        U4DVector3n dir(1,1,1);
//        
//        U4DSimplexStruct c=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//        
//        dir.negate();
//        
//        U4DSimplexStruct b=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//        
//        //test if the last point added past the origin
//        if (b.minkowskiPoint.toVector().dot(dir)<0) {
//            
//            //if it did not passed the origin, then there is no way for the simplex to contain the point
//            return false;
//        }
//        
//        //adding simplex struct to container
//        Q.push_back(c);
//        Q.push_back(b);
//        
//        while (iterationSteps<25) {
//            
//            //2. Compute the point P of minimum norm in CH(Q)
//            
//            closestPtToOrigin=determineClosestPointOnSimplexToPoint(originPoint, Q);
//            
//            /*
//             3. If P is the origin itself, the origin is clearly contained in the Minkowski difference
//                of A and B. Stop and return A and B as intersecting.
//             */
//            if (closestPtToOrigin==originPoint) {
//                
//                
//                //since collision is true, get the closest collision points
//                
//                closestPointToOrigin=originPoint;
//                
//                //get the barycentric points of the collision
//                std::vector<float> barycentricPoints=determineBarycentricCoordinatesInSimplex(closestPointToOrigin, Q);
//    
//                U4DPoint3n closestPointsModel1(0,0,0);
//                U4DPoint3n closestPointsModel2(0,0,0);
//    
//                for (int i=0; i<barycentricPoints.size(); i++) {
//    
//                    closestPointsModel1+=Q.at(i).sa*barycentricPoints.at(i);
//                    closestPointsModel2+=Q.at(i).sb*barycentricPoints.at(i);
//                }
//    
//                U4DVector3n contactPoint1=closestPointsModel1.toVector();
//    
//                uModel1->setCollisionContactPoint(contactPoint1);
//                
//                U4DVector3n contactPoint2=closestPointsModel2.toVector();
//                
//                uModel2->setCollisionContactPoint(contactPoint2);
//                
//                return true;
//            }
//            
//            /*
//             4. Reduce Q to the smallest subset Q' of Q such that P is in CH(Q'). That is, remove
//             any points from Q not determining the subsimplex of Q in which P lies.
//            */
//            
//            determineMinimumSimplexInQ(closestPtToOrigin,Q.size());
//            
//            // 5. Let V=Sb(-p)-sa(p) be a supporting point in direction -P.
//            
//            dir=closestPtToOrigin.toVector();
//            
//            dir.negate();
//            
//            U4DSimplexStruct v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
//            
//            /*
//             6. If V is no more extremal in direction -P than P itself, stop and return A and B as not
//             intersecting. The length of the vector from the origin to P is the separation distance of
//             A and B.
//             */
//            
//            if (v.minkowskiPoint.toVector().dot(dir)<0.0 || v.minkowskiPoint==tempV) {
//               
//                
//                return false;
//            }
//            
//            /*
//             7. Add V to Q and got to step 2.
//             */
//            
//            tempV=v.minkowskiPoint;
//            
//            Q.push_back(v);
//            
//            iterationSteps++;
//        }
//
//        //undefined collision state
//        return false;
        
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
    
    std::vector<U4DPoint3n> U4DGJKAlgorithm::closestBarycentricPoints(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ){
        
        //get the barycentric points of the collision
        std::vector<float> barycentricPoints=determineBarycentricCoordinatesInSimplex(uClosestPointToOrigin, uQ);
        
        U4DPoint3n closestPointsModel1(0,0,0);
        U4DPoint3n closestPointsModel2(0,0,0);
        
        for (int i=0; i<barycentricPoints.size(); i++) {
            
            closestPointsModel1+=uQ.at(i).sa*barycentricPoints.at(i);
            closestPointsModel2+=uQ.at(i).sb*barycentricPoints.at(i);
        }
        
        
        std::vector<U4DPoint3n> closestPoints{closestPointsModel1,closestPointsModel2};
        
        return closestPoints;
        
    }
    
    float U4DGJKAlgorithm::distanceToCollision(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ){
        
        //get the barycentric points of the collision
        std::vector<float> barycentricPoints=determineBarycentricCoordinatesInSimplex(uClosestPointToOrigin, Q);
        
        U4DPoint3n closestPointsModel1(0,0,0);
        U4DPoint3n closestPointsModel2(0,0,0);
        
        for (int i=0; i<barycentricPoints.size(); i++) {
            
            closestPointsModel1+=Q.at(i).sa*barycentricPoints.at(i);
            closestPointsModel2+=Q.at(i).sb*barycentricPoints.at(i);
        }
        
        
        U4DVector3n distanceVector=closestPointsModel1-closestPointsModel2;
        
        return distanceVector.magnitude();
        
    }
    
    std::vector<U4DSimplexStruct> U4DGJKAlgorithm::getCurrentSimpleStruct(){
        
        return Q;
        
    }
    
    U4DPoint3n U4DGJKAlgorithm::getClosestPointToOrigin(){
        return closestPointToOrigin;
    }
}