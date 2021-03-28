//
//  U4DNumerical.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/6/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#include "U4DNumerical.h"
#include <cmath>
#include <algorithm>

namespace U4DEngine {
    
    U4DNumerical::U4DNumerical(){
        
    }
    
    U4DNumerical::~U4DNumerical(){
        
    }
    
    bool U4DNumerical::areEqualAbs(float uNumber1, float uNumber2, float uEpsilon){
        
        return (fabs(uNumber1-uNumber2)<=uEpsilon);
        
    }
    
    
    bool U4DNumerical::areEqualRel(float uNumber1, float uNumber2, float uEpsilon){
       
        return (fabs(uNumber1-uNumber2)<=uEpsilon*std::max(fabs(uNumber1),fabs(uNumber2)));
                
    }
    
    
    bool U4DNumerical::areEqual(float uNumber1, float uNumber2, float uEpsilon){
        
        return (fabs(uNumber1-uNumber2)<=uEpsilon*std::max(1.0f,std::max(fabs(uNumber1),fabs(uNumber2))));
        
    }
    
    float U4DNumerical::getRandomNumberBetween(float uMinValue, float uMaxValue){
        
        float randNumber=(arc4random()/(double)UINT32_MAX);
        
        float diff=uMaxValue-uMinValue;
        
        float r=randNumber*diff;
        
        return uMinValue+r;
    }

    float U4DNumerical::remapValue(float uValue,U4DVector2n &uRangeFrom, U4DVector2n &uRangeTo){
        
        float mappedValue = uRangeTo.x + (uRangeTo.y - uRangeTo.x) * ((uValue - uRangeFrom.x) / (uRangeFrom.y - uRangeFrom.x));
        
        return mappedValue;
    }

    matrix_float4x4 U4DNumerical::convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix){
        
        // 4x4 matrix - column major. X vector is 0, 1, 2, etc.
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        matrix_float4x4 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        m.columns[0][3]=uMatrix.matrixData[3];
        
        m.columns[1][0]=uMatrix.matrixData[4];
        m.columns[1][1]=uMatrix.matrixData[5];
        m.columns[1][2]=uMatrix.matrixData[6];
        m.columns[1][3]=uMatrix.matrixData[7];
        
        m.columns[2][0]=uMatrix.matrixData[8];
        m.columns[2][1]=uMatrix.matrixData[9];
        m.columns[2][2]=uMatrix.matrixData[10];
        m.columns[2][3]=uMatrix.matrixData[11];
        
        m.columns[3][0]=uMatrix.matrixData[12];
        m.columns[3][1]=uMatrix.matrixData[13];
        m.columns[3][2]=uMatrix.matrixData[14];
        m.columns[3][3]=uMatrix.matrixData[15];
        
        return m;
        
    }
    
    matrix_float3x3 U4DNumerical::convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix){
        
        //    0    3    6
        //    1    4    7
        //    2    5    8
        
        matrix_float3x3 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        
        m.columns[1][0]=uMatrix.matrixData[3];
        m.columns[1][1]=uMatrix.matrixData[4];
        m.columns[1][2]=uMatrix.matrixData[5];
        
        m.columns[2][0]=uMatrix.matrixData[6];
        m.columns[2][1]=uMatrix.matrixData[7];
        m.columns[2][2]=uMatrix.matrixData[8];
        
        return m;
        
    }
    
    vector_float4 U4DNumerical::convertToSIMD(U4DEngine::U4DVector4n &uVector){
        
        vector_float4 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        v.z=uVector.z;
        v.w=uVector.w;
        
        return v;
    }
    
    vector_float3 U4DNumerical::convertToSIMD(U4DEngine::U4DVector3n &uVector){
        
        vector_float3 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        v.z=uVector.z;
        
        return v;
    }
    
    vector_float2 U4DNumerical::convertToSIMD(U4DEngine::U4DVector2n &uVector){
        
        vector_float2 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        
        return v;
    }

}
