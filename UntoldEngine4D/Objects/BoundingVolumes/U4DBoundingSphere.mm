//
//  U4DBoundingSphere.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DBoundingSphere.h"
#include "U4DMatrix4n.h"

namespace U4DEngine {
    
    U4DBoundingSphere::U4DBoundingSphere(){
    
    }
    
    
    U4DBoundingSphere::~U4DBoundingSphere(){
    
    }
    
    
    U4DBoundingSphere::U4DBoundingSphere(const U4DBoundingSphere& value){
        radius=value.radius;
    };
    
    
    U4DBoundingSphere& U4DBoundingSphere::operator=(const U4DBoundingSphere& value){
        
        radius=value.radius;
        return *this;
        
    };
    
    void U4DBoundingSphere::computeBoundingVolume(float uRadius,int uRings, int uSectors){

        radius=uRadius;
        float R=1.0/(uRings-1);
        float S=1.0/(uSectors-1);
        
        int r,s;
        
        
        for (r=0; r<uRings; r++) {
            
            for (s=0; s<uSectors; s++) {
                
                float uY=sin(-M_PI_2+M_PI*r*R);
                float uX=cos(2*M_PI * s * S) * sin( M_PI * r * R );
                float uZ=sin(2*M_PI * s * S) * sin( M_PI * r * R );
                
                uX*=uRadius;
                uY*=uRadius;
                uZ*=uRadius;
                
                U4DVector3n vec(uX,uY,uZ);
                
                bodyCoordinates.addVerticesDataToContainer(vec);
               
                //push to index
                
                int curRow=r*uSectors;
                int nextRow=(r+1)*uSectors;
                
                U4DIndex index(curRow+s,nextRow+s,nextRow+(s+1));
                bodyCoordinates.addIndexDataToContainer(index);
                
                U4DIndex index2(curRow+s,nextRow+s,curRow+(s+1));
                bodyCoordinates.addIndexDataToContainer(index2);
                
            }
        }
        
        loadRenderingInformation();
        
    }

    /*
    void U4DBoundingSphere::initSphere(float uRadius,U4DVector3n& uOffset,int uRings, int uSectors){
        
        radius=uRadius;
        offset=uOffset;
        
        float R=1.0/(uRings-1);
        float S=1.0/(uSectors-1);
        
        int r,s;
        
        
        for (r=0; r<uRings; r++) {
            
            for (s=0; s<uSectors; s++) {
                
                float uX=cos(2*M_PI * s * S) * sin( M_PI * r * R );
                float uY=sin(-M_PI_2+M_PI*r*R);
                float uZ=sin(2*M_PI * s * S) * sin( M_PI * r * R );
                
                uX*=uRadius;
                uY*=uRadius;
                uZ*=uRadius;
                
                U4DVector3n vec(uX,uY,uZ);
                mesh.Position.push_back(vec);
                
                
                //push to index
                
                int curRow=r*uSectors;
                int nextRow=(r+1)*uSectors;
                
                U4DIndex index(curRow+s,nextRow+s,nextRow+(s+1));
                
                mesh.Index.push_back(index);
                
                U4DIndex index2(curRow+s,nextRow+s,curRow+(s+1));
                
                mesh.Index.push_back(index2);
                
                
            }
        }
        
        //transform the vertices by the offset vector
        U4DMatrix4n mat;
        mat.matrixData[12]=uOffset.x;
        mat.matrixData[13]=uOffset.y;
        mat.matrixData[14]=uOffset.z;
        
        for (int i=0; i<openGlManager->geometricVertices.size(); i++) {
            
            U4DVector3n ver=mat.transform(openGlManager->geometricVertices.at(i).getVertices());
            
            openGlManager->geometricVertices.at(i).setVertices(ver.x, ver.y, ver.z);
           
        }
        
        assembleGeometry();
     
    }
     */

}