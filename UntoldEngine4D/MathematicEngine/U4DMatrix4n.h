//
//  U4DMatrix4n.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DMatrix4n__
#define __MathLibrary__U4DMatrix4n__

#include <iostream>

namespace U4DEngine {
class U4DMatrix3n;
class U4DVector3n;
class U4DQuaternion;
}


namespace U4DEngine {
/**
 *  Class in charge of 4N matrix
 */
class U4DMatrix4n{
    
public:
    
    /**
     *  Matrix data elements
     */
    float matrixData[16]={0};
    
    /**
     *  Constructor
     */
    U4DMatrix4n(){
      
        // 4x4 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        for (int i=0; i<16; i++) {
            matrixData[i]=0.0f;
        }
        
        matrixData[0]=matrixData[5]=matrixData[10]=matrixData[15]=1.0f;
        
    };
    
    /**
     *  Constructor
     */
    U4DMatrix4n(float m0,float m4,float m8,float m12,float m1,float m5,float m9,float m13,float m2,float m6,float m10,float m14,float m3,float m7, float m11,float m15){
        
        matrixData[0]=m0;
        matrixData[4]=m4;
        matrixData[8]=m8;
        matrixData[12]=m12;
        
        matrixData[1]=m1;
        matrixData[5]=m5;
        matrixData[9]=m9;
        matrixData[13]=m13;
        
        matrixData[2]=m2;
        matrixData[6]=m6;
        matrixData[10]=m10;
        matrixData[14]=m14;
        
        matrixData[3]=m3;
        matrixData[7]=m7;
        matrixData[11]=m11;
        matrixData[15]=m15;
        
    }
    
    /**
     *  Copy Constructor
     */
    U4DMatrix4n& operator=(const U4DMatrix4n& value){
   
        for (int i=0; i<16; i++) {
            matrixData[i]=value.matrixData[i];
        }
    
        return *this;
    };
    
    
    ~U4DMatrix4n(){}
    
    U4DMatrix4n operator*(const U4DMatrix4n& m)const;
    
    
    U4DMatrix4n multiply(const U4DMatrix4n& m)const;
    
    
    void operator*=(const U4DMatrix4n& m);
    
    
    U4DVector3n operator*(const U4DVector3n& v) const;
    
    
    U4DVector3n transform(const U4DVector3n& v) const;
    
    
    float getDeterminant() const;
    
    
    void setInverse(const U4DMatrix4n& m);
    
    
    U4DMatrix4n inverse()const;
    
    
    void invert();
    
    
    U4DMatrix3n extract3x3Matrix();
    
    
    void setTranspose(const U4DMatrix4n& m);
    
    
    U4DMatrix4n transpose() const;
    
    void computePerspectiveMatrix(float fov, float aspect, float near, float far);
    
    void computeOrthographicMatrix(float left, float right,float bottom,float top,float near, float far);
    
    void show();
    
};
    
}

#endif /* defined(__MathLibrary__U4DMatrix4n__) */
