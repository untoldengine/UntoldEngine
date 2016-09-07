//
//  U4DSegment.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DSegment.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    U4DSegment::U4DSegment():pointA(0.0,0.0,0.0),pointB(0.0,0.0,0.0){
    
    }
    
    U4DSegment::U4DSegment(U4DPoint3n& uPointA,U4DPoint3n& uPointB){
        
        pointA=uPointA;
        pointB=uPointB;
    }
    
    U4DSegment::U4DSegment(const U4DSegment& a):pointA(a.pointA),pointB(a.pointB){
        
    }
    
    
    U4DSegment& U4DSegment::operator=(const U4DSegment& a){
        
        pointA=a.pointA;
        pointB=a.pointB;
        
        return *this;
        
    }

    U4DSegment::~U4DSegment(){
        
    }
    
    bool U4DSegment::operator==(const U4DSegment& uSegment){
        
        if (pointA==uSegment.pointA && pointB==uSegment.pointB) {
            return true;
        }else{
            return false;
        }
    }


    bool U4DSegment::operator!=(const U4DSegment& uSegment){
        
        if (pointA!=uSegment.pointA && pointB!=uSegment.pointB) {
            return true;
        }else{
            return false;
        }
    }
    
    U4DSegment U4DSegment::negate(){
                
        U4DSegment ba(pointB,pointA);
        
        return ba;
        
    }
    
    

    U4DPoint3n U4DSegment::closestPointOnSegmentToPoint(U4DPoint3n& uPoint){
        
        float t;
        U4DPoint3n d;
        
        U4DVector3n ab=pointA-pointB;
        
        //project c onto ab, but deferring divide by dot(ab,ab)
        
        t=(pointA-uPoint).dot(ab);
        
        if (t<=0.0f) {
            //c projects outside the [a,b] interval, on the a side; clamp to a
            
            t=0.0f;
            
            return pointA;
            
            
        }else{
            float denom=ab.dot(ab); //always nonnegative since denom=||ab||^2
            
            if (t>=denom) {
                //c projects outside the [a,b] interval, on the b side; clamp to b
                
                t=1.0f;
                
                return pointB;
                
            }else{
                
                //c projects inside the [a,b] interval; must do deferred divide now
                
                t=t/denom;
                
                U4DPoint3n p;
                
                p.convertVectorToPoint(ab);
            
                
                return pointA+p*t;
                
            }
        }
        
    }

    bool U4DSegment::isPointOnSegment(U4DPoint3n& uPoint){
        
        //return true if point is close enough to line
        if (sqDistancePointSegment(uPoint)<0.001f){
            
            return true;
            
        }else{
            return false;
        }
    }

    float U4DSegment::sqDistancePointSegment(U4DPoint3n& uPoint){
        
        U4DVector3n ab=pointA-pointB;
        U4DVector3n ac=pointA-uPoint;
        U4DVector3n bc=pointB-uPoint;
        
        float e=ac.dot(ab);
        
        //Handle cases where c projects outside ab
        
        if (e<=0.0f) return ac.dot(ac);
        
        float f=ab.dot(ab);
        
        if (e>=f) return bc.dot(bc);
        
        //Handle cases where c projects onto ab
        
        return ac.dot(ac)-e*(e/f);
    }
    
    float U4DSegment::normalizedSquareDistancePointSegment(U4DPoint3n& uPoint){
        
        U4DVector3n ab=pointA-pointB;
        U4DVector3n ac=pointA-uPoint;
        U4DVector3n bc=pointB-uPoint;
        
        //normalize the vectors
        ab.normalize();
        ac.normalize();
        bc.normalize();
        
        float e=ac.dot(ab);
        
        //Handle cases where c projects outside ab
        
        if (e<=0.0f) return ac.dot(ac);
        
        float f=ab.dot(ab);
        
        if (e>=f) return bc.dot(bc);
        
        //Handle cases where c projects onto ab
        
        return ac.dot(ac)-e*(e/f);
        
    }
        
        
    void U4DSegment::getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV){
        
        float t;
        U4DPoint3n d;
        
        U4DVector3n ab=pointA-pointB;
        
        //project c onto ab, but deferring divide by dot(ab,ab)
        
        t=(pointA-uPoint).dot(ab);
        
        if (t<=0.0f) {
            //c projects outside the [a,b] interval, on the a side; clamp to a
            
            t=0.0f;
            
        }else{
            float denom=ab.dot(ab); //always nonnegative since denom=||ab||^2
            
            if (t>=denom) {
                //c projects outside the [a,b] interval, on the b side; clamp to b
                
                
                t=1.0f;
                
            }else{
                
                //c projects inside the [a,b] interval; must do deferred divide now
                
                t=t/denom;
                
            }
        }

        baryCoordinateU=1-t;
        baryCoordinateV=t;

    }
    
    bool U4DSegment::isValid(){
        
        if (pointA!=pointB) {
            return true;
        }else{
            return false;
        }
        
    }
    
    std::vector<U4DPoint3n> U4DSegment::getPoints(){
        
        std::vector<U4DPoint3n> points{pointA,pointB};
    
        return points;
    }
    
    void U4DSegment::show(){
        
        std::cout<<"Point A: "<<std::endl;
        pointA.show();
        std::cout<<"Point B: "<<std::endl;
        pointB.show();
        
        if (isValid()) {
            std::cout<<"Segment is Valid"<<std::endl;
        }else{
            std::cout<<"Segment is not valid"<<std::endl;
        }
        
    }

}