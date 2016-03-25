//
//  U4DOBB.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DOBB.h"
#include <cmath>
#include <vector>

namespace U4DEngine {
    
    U4DOBB::U4DOBB(U4DVector3n& uHalfWidth){
      
        halfwidth=uHalfWidth;
        orientation.setIdentity(); //set matrix as identity
        center.zero(); //set the center(0,0,0)
        
    }

    U4DOBB::U4DOBB(U4DVector3n& uHalfWidth, U4DVector3n& uCenter, U4DMatrix3n& uOrientation){
        
        halfwidth=uHalfWidth;
        center=uCenter;
        orientation=uOrientation;
        
    }

    bool U4DOBB::intersectionWithVolume(U4DPlane& uPlane){
        
        //compute the projection interval radius of b onto L(t)
        
        float r=(halfwidth.x*2.0)*std::abs(uPlane.n.dot(orientation.getFirstColumnVector()))+(halfwidth.y*2.0)*std::abs(uPlane.n.dot(orientation.getSecondColumnVector()))+(halfwidth.z*2.0)*std::abs(uPlane.n.dot(orientation.getThirdColumnVector()));
        
        
        //compute distance of box center from plane
        float s=uPlane.n.dot(center)-uPlane.d;
        
        //intersection occurs when distance s falls within [-r,+r] interval
        return std::abs(s)<=r;
        
    }

    bool U4DOBB::intersectionWithVolume(U4DOBB* uOBB){
        
        float ra,rb;
        U4DMatrix3n R;
        U4DMatrix3n absR;
        
        U4DVector3n raHalfWidth=halfwidth*2.0;
        U4DVector3n rbHalfWidth=uOBB->halfwidth*2.0;
        
        // 3x3 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
        //	0	3	6
        //	1	4	7
        //	2	5	8
        
        
        //compute rotation matrix expressing b into a's coordinate frame
        
        R=orientation*uOBB->orientation;
        
        for (int i=0; i<9; i++) {
            absR.matrixData[i]=std::abs(R.matrixData[i])+0.01;
        }
        //compute translation vector
        U4DVector3n t=center-uOBB->center;
      
        //bring translation into a's coordinate frame
        U4DVector3n ta(t.dot(orientation.getFirstColumnVector()),t.dot(orientation.getSecondColumnVector()),t.dot(orientation.getThirdColumnVector()));
        
        
        float absr00=absR.matrixData[0];
        float absr01=absR.matrixData[1];
        float absr02=absR.matrixData[2];
        
        float absr10=absR.matrixData[3];
        float absr11=absR.matrixData[4];
        float absr12=absR.matrixData[5];
        
        float absr20=absR.matrixData[6];
        float absr21=absR.matrixData[7];
        float absr22=absR.matrixData[8];
        
        
        float r00=R.matrixData[0];
        float r01=R.matrixData[1];
        float r02=R.matrixData[2];
        
        float r10=R.matrixData[3];
        float r11=R.matrixData[4];
        float r12=R.matrixData[5];
        
        float r20=R.matrixData[6];
        float r21=R.matrixData[7];
        float r22=R.matrixData[8];
        
        //test axes L=A0, L=A1,L=A2
       
        ra=raHalfWidth.x;
        rb=rbHalfWidth.x*absr00+rbHalfWidth.y*absr01+rbHalfWidth.z*absr02;
        
        if (std::abs(ta.x)>(ra+rb)) return 0;
        
        ra=raHalfWidth.y;
        rb=rbHalfWidth.x*absr10+rbHalfWidth.y*absr11+rbHalfWidth.z*absr12;
        
        if (std::abs(ta.y)>(ra+rb)) return 0;
        
        ra=raHalfWidth.z;
        rb=rbHalfWidth.x*absr20+rbHalfWidth.y*absr21+rbHalfWidth.z*absr22;
        
        if (std::abs(ta.z)>(ra+rb)) return 0;
        
        //Test axis L=B0, L=B1, L=B2
        
        rb=rbHalfWidth.x;
        ra=raHalfWidth.x*absr00+raHalfWidth.y*absr10+raHalfWidth.z*absr20;
        
        if (std::abs(ta.x*r00+ta.y*r10+ta.z*r20)>(ra+rb)) return 0;
        
        rb=rbHalfWidth.y;
        ra=raHalfWidth.x*absr01+raHalfWidth.y*absr11+raHalfWidth.z*absr21;
        
        if (std::abs(ta.x*r01+ta.y*r11+ta.z*r21)>(ra+rb)) return 0;
        
        rb=rbHalfWidth.z;
        ra=raHalfWidth.x*absr02+raHalfWidth.y*absr12+raHalfWidth.z*absr22;
        
        if (std::abs(ta.x*r02+ta.y*r12+ta.z*r22)>(ra+rb)) return 0;
        
        
        //Test axis L=A0xB0
        ra=raHalfWidth.y*absr20+raHalfWidth.z*absr10;
        rb=rbHalfWidth.y*absr02+rbHalfWidth.z*absr01;
        
        if (std::abs(ta.z*r10-ta.y*r20)>(ra+rb)) return 0;
        
        //Test axis L=A0xB1
        ra=raHalfWidth.y*absr21+raHalfWidth.z*absr11;
        rb=rbHalfWidth.x*absr02+rbHalfWidth.z*absr00;
        
        if (std::abs(ta.z*r11-ta.y*r21)>(ra+rb)) return 0;
        
        //Test axis L=A0xB2
        ra=raHalfWidth.y*absr22+raHalfWidth.z*absr12;
        rb=rbHalfWidth.x*absr01+rbHalfWidth.y*absr00;
        
        if (std::abs(ta.z*r12-ta.y*r22)>(ra+rb)) return 0;
        
        //Test axis L=A1xB0
        
        ra=raHalfWidth.x*absr20+raHalfWidth.z*absr00;
        rb=rbHalfWidth.y*absr12+rbHalfWidth.z*absr11;
        
        if (std::abs(ta.x*r20-ta.z*r00)>(ra+rb)) return 0;
        
        //Test axis L=A1xB1
        ra=raHalfWidth.x*absr21+raHalfWidth.z*absr01;
        rb=rbHalfWidth.x*absr12+rbHalfWidth.z*absr10;
        
        if (std::abs(ta.x*r21-ta.z*r01)>(ra+rb)) return 0;
        
        //Test axis L=A1xB2
        ra=raHalfWidth.x*absr22+raHalfWidth.z*absr02;
        rb=rbHalfWidth.x*absr11+rbHalfWidth.y*absr10;
        
        if (std::abs(ta.x*r22-ta.z*r02)>(ra+rb)) return 0;
        
        //Test axis L=A2xB0
        ra=raHalfWidth.x*absr10+raHalfWidth.y*absr00;
        rb=rbHalfWidth.y*absr22+rbHalfWidth.z*absr21;
        
        if (std::abs(ta.y*r00-ta.x*r10)>(ra+rb)) return 0;
        
        //Test axis L=A2xB1
        ra=raHalfWidth.x*absr11+raHalfWidth.y*absr01;
        rb=rbHalfWidth.x*absr22+rbHalfWidth.z*absr20;
        
        if (std::abs(ta.y*r01-ta.x*r11)>(ra+rb)) return 0;
        
        //Test axis L=A2xB2
        ra=raHalfWidth.x*absr12+raHalfWidth.y*absr02;
        rb=rbHalfWidth.x*absr21+rbHalfWidth.y*absr20;
        
        if (std::abs(ta.y*r02-ta.x*r12)>(ra+rb)) return 0;
        
        
        //since no separating axis is found, the OBBs must be intersecting
        return 1;
    }


    U4DVector3n U4DOBB::closestPointToOBB(U4DVector3n& uPoint){
        
        U4DVector3n d=uPoint-center;
        
        U4DVector3n q;
        
        
        //start result at center of box; make steps from there
        q=center;
        
        U4DVector3n uAxis[3];
        
        uAxis[0]=orientation.getFirstColumnVector();
        uAxis[1]=orientation.getSecondColumnVector();
        uAxis[2]=orientation.getThirdColumnVector();
        
        
        float eHalfSpace[3];
        
        eHalfSpace[0]=halfwidth.x*2.0;
        eHalfSpace[1]=halfwidth.y*2.0;
        eHalfSpace[2]=halfwidth.z*2.0;
        
        
        //for each OBB axis...
        for (int i=0; i<3; i++) {
            
            //...project d onto that axis to get the distance along the axis of d from the box center
            float dist=d.dot(uAxis[i]);
            
            //if distance farther than the box extents, clamp to the box
            if (dist>eHalfSpace[i]) {
                dist=eHalfSpace[i];
            }
            
            if (dist<-eHalfSpace[i]) {
                dist=-eHalfSpace[i];
            }
            
            //step that distance along the axis to get world coordinate
            
            q+=uAxis[i]*dist;
            
        }
        
        return q;
        
    }

    float U4DOBB::sqDistPointOBB(U4DVector3n& uPoint){
        
        U4DVector3n closest=closestPointToOBB(uPoint);
        
        float sqDist=(closest-uPoint).dot(closest-uPoint);
        
        return sqDist;
    }



    std::vector<U4DVector3n> U4DOBB::computeVertexIntersectingPlane(U4DPlane& uPlane){
        
        std::vector<U4DVector3n> intersectingVertex;
        
        //compute the vertices
        float width=halfwidth.x*2.0;
        float height=halfwidth.y*2.0;
        float depth=halfwidth.z*2.0;
        
        U4DVector3n v1(width,height,depth);
        U4DVector3n v2(width,height,-depth);
        U4DVector3n v3(-width,height,-depth);
        U4DVector3n v4(-width,height,depth);
        
        U4DVector3n v5(width,-height,depth);
        U4DVector3n v6(width,-height,-depth);
        U4DVector3n v7(-width,-height,-depth);
        U4DVector3n v8(-width,-height,depth);
        
        
        std::vector<U4DVector3n> vertices{v1,v2,v3,v4,v5,v6,v7,v8};
        std::vector<U4DVector3n> transformedVertices;
        
        //transform the vertices
        for (int i=0; i<vertices.size(); i++) {
            
            U4DVector3n vertex=orientation*vertices.at(i);
            
            vertex=vertex+center;
            
            transformedVertices.push_back(vertex);
            
        }
        
        //for each vertex, check if its above/below the plane
        
        //if p*n=0, its on the plane
        //if p*n<0, its below plane
        //if p*n>0, its above plane
        
        
        for (int i=0; i<transformedVertices.size(); i++) {
            
            if (uPlane.n.dot(transformedVertices.at(i))<0) {
                
            
                U4DVector3n vertex=transformedVertices.at(i);
                
                vertex=(vertex-center)/2.0;
                
                
                intersectingVertex.push_back(vertex);
                
            }
            
        }
        
        return intersectingVertex;
        
    }


}



