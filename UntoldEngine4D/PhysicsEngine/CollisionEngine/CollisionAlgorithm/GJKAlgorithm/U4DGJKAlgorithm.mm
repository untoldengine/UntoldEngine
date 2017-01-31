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
    
    U4DGJKAlgorithm::U4DGJKAlgorithm(){
    
    }
    
    U4DGJKAlgorithm::~U4DGJKAlgorithm(){
    
    }
    
    bool U4DGJKAlgorithm::collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){
        
        //version 3 of the GJK-TOI implementation
        
        //clear Q
        cleanUp();
        
        U4DPoint3n originPoint(0,0,0);
        U4DPoint3n tempV(0,0,0); //variable to store previous value of v
        std::vector<float> barycentricPoints; //barycentric points
        float tClip=0.0; //time of impact
        U4DVector3n hitSpot(0,0,0); //hit spot
        U4DVector3n relativeCSOTranslation(0,0,0); //relative CSO translation
        int iterationSteps=0;
        
        U4DBoundingVolume *boundingVolume1=uModel1->getNarrowPhaseBoundingVolume();
        U4DBoundingVolume *boundingVolume2=uModel2->getNarrowPhaseBoundingVolume();
        
        relativeCSOTranslation=uModel1->getAbsolutePosition()-uModel2->getAbsolutePosition();
        
        relativeCSOTranslation.normalize();
        
        U4DVector3n dir(1,1,1);
        
        SIMPLEXDATA v=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        Q.push_back(v);
        
        dir=v.minkowskiPoint.toVector();
        
        dir.negate();
        
        SIMPLEXDATA p=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
        
        while (v.minkowskiPoint.magnitudeSquare()-v.minkowskiPoint.toVector().dot(p.minkowskiPoint.toVector())>U4DEngine::collisionDistanceEpsilon*U4DEngine::collisionDistanceEpsilon) {
            
            if (iterationSteps>10) {
                return false;
            }
            
            if (v.minkowskiPoint.toVector().dot(p.minkowskiPoint.toVector())>(v.minkowskiPoint.toVector().dot(relativeCSOTranslation))*tClip) {
                
                if (v.minkowskiPoint.toVector().dot(relativeCSOTranslation)>0.0) {
                    
                    tClip=v.minkowskiPoint.toVector().dot(p.minkowskiPoint.toVector())/v.minkowskiPoint.toVector().dot(relativeCSOTranslation);
                    
                    if (tClip>1.0) {
                        return false;
                    }
                    
                    hitSpot=relativeCSOTranslation*tClip;
                    
                    closestPointToOrigin=v.minkowskiPoint;
                    
                    contactCollisionNormal=v.minkowskiPoint.toVector();
                    
                    Q.clear();
                    
                    //set time of impact for each model.
                    
                    if (tClip<U4DEngine::minimumTimeOfImpact) {
                        
                        //minimum time step allowed
                        uModel1->setTimeOfImpact(U4DEngine::minimumTimeOfImpact);
                        uModel2->setTimeOfImpact(U4DEngine::minimumTimeOfImpact);
                        
                    }else{
                        
                        uModel1->setTimeOfImpact(tClip);
                        uModel2->setTimeOfImpact(tClip);
                        
                    }
                    
                }else{
                    return false;
                }
            }
            
            //p-hitSpot
            p.minkowskiPoint=(hitSpot.toPoint()-p.minkowskiPoint).toPoint();
            
            Q.push_back(p);
            
            v.minkowskiPoint=determineClosestPointOnSimplexToPoint(originPoint, Q);
            
            determineMinimumSimplexInQ(v.minkowskiPoint,Q.size());
            
            dir=v.minkowskiPoint.toVector();
            
            dir.negate();
            
            p=calculateSupportPointInDirection(boundingVolume1, boundingVolume2, dir);
            
            iterationSteps++;
        }
        
        if (Q.size()<2 || Q.size()>4) {
            return false;
        }
                
        if (v.minkowskiPoint.magnitude()>U4DEngine::collisionDistanceEpsilon) {
            return false;
        }
        
        
        //if contact collision normal=0.0, then set the contact collision normal to the relative translation
        if (contactCollisionNormal==U4DVector3n(0.0,0.0,0.0)) {
            
            contactCollisionNormal=relativeCSOTranslation;
            
        }
        
        //normalize contact normal
        contactCollisionNormal.normalize();
        
        //closest collision point
        std::vector<U4DPoint3n> closestCollisionPoints=closestBarycentricPoints(closestPointToOrigin, Q);
        
        //Once there is a contact,the closestBarycentricPoints returns two identical closest points. I'm assigning the first
        //point in the vector as the closesCollisionPoint.
        closestCollisionPoint=closestCollisionPoints.at(0);
        
        //reset time of impact
        uModel1->resetTimeOfImpact();
        
        uModel2->resetTimeOfImpact();
        
       return true;
        
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
        
        SIMPLEXDATA tempSupportPointQA=Q.at(0);
        SIMPLEXDATA tempSupportPointQB=Q.at(1);
        
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
        
        SIMPLEXDATA tempSupportPointQA=Q.at(0);
        SIMPLEXDATA tempSupportPointQB=Q.at(1);
        SIMPLEXDATA tempSupportPointQC=Q.at(2);
        
        
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
        
        
        SIMPLEXDATA tempSupportPointQA=Q.at(0);
        SIMPLEXDATA tempSupportPointQB=Q.at(1);
        SIMPLEXDATA tempSupportPointQC=Q.at(2);
        SIMPLEXDATA tempSupportPointQD=Q.at(3);
        
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
    
    std::vector<U4DPoint3n> U4DGJKAlgorithm::closestBarycentricPoints(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ){
        
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
    
    float U4DGJKAlgorithm::distanceToCollision(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ){
        
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
    
    std::vector<SIMPLEXDATA> U4DGJKAlgorithm::getCurrentSimpleStruct(){
        
        return Q;
        
    }
    
    U4DPoint3n U4DGJKAlgorithm::getClosestPointToOrigin(){
        
        return closestPointToOrigin;
        
    }
    
    U4DPoint3n U4DGJKAlgorithm::getClosestCollisionPoint(){
        
        return closestCollisionPoint;
        
    }
    
    U4DVector3n U4DGJKAlgorithm::getContactCollisionNormal(){
        
        return contactCollisionNormal;
    }
    
    void U4DGJKAlgorithm::cleanUp(){
        Q.clear();
        
        //Commented these values
        //closestPointToOrigin.zero();
        //closestCollisionPoint.zero();
        //contactCollisionNormal=U4DVector3n(0,1,0);
    }
    
}
