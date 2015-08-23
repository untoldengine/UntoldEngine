//
//  U4DU4DDualQuaternion.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DDualQuaternion__
#define __MathLibrary__U4DDualQuaternion__

#include <iostream>
#include "U4DQuaternion.h"
#include "U4DVector3n.h"

namespace U4DEngine {
 
class U4DDualQuaternion{

public:
    
    /**
     *  real part of dual quaternion-Orientation
     */
    U4DQuaternion qReal;
    
    /**
     *  pure part of dual quaternion-Translation
     */
    U4DQuaternion qPure;
    
    
    U4DDualQuaternion(){
        
        U4DVector3n vec(0,0,0);
        U4DQuaternion q(0,vec);
        q.convertToUnitNormQuaternion();
        
        qReal=q;
        
        U4DQuaternion t(0,vec);
        
        U4DQuaternion d=(t*qReal)*0.5;
        
        qPure=d;
        
    }
    
    
    U4DDualQuaternion(const U4DQuaternion &q,U4DVector3n& v){
        
        qReal=q;
        
        U4DQuaternion t(0,v);
        
        U4DQuaternion d=(t*qReal)*0.5;
        
        qPure=d;
    }
    
    
    
    U4DDualQuaternion(const U4DQuaternion &q,U4DQuaternion& v){
     
        qReal=q;
        qPure=v;
        
    }
    
    
    U4DDualQuaternion(const U4DDualQuaternion& value){
    
        qReal=value.qReal;
        qPure=value.qPure;
        
    };
    
    
    U4DDualQuaternion& operator=(const U4DDualQuaternion& value){
        
        qReal=value.qReal;
        qPure=value.qPure;
        
        return *this;
    };
    
    
    ~U4DDualQuaternion(){};
    
    
    void operator+=(const U4DDualQuaternion& q);
    
    
    U4DDualQuaternion operator+(const U4DDualQuaternion& q)const;
   
    
    void operator*=(const U4DDualQuaternion& q);
    
   
    U4DDualQuaternion operator*(const U4DDualQuaternion& q)const;

    
    U4DDualQuaternion multiply(const U4DDualQuaternion& q)const;
    
    U4DDualQuaternion operator*(const float value);
    
    float dot(U4DDualQuaternion& q);
    
    U4DDualQuaternion normalize();
    
    U4DDualQuaternion conjugate();
    
    U4DQuaternion getRealQuaternionPart();
    
    U4DQuaternion getPureQuaternionPart();
    
    U4DMatrix4n transformDualQuaternionToMatrix4n();
    
    void transformMatrix4nToDualQuaternion(U4DMatrix4n &uMatrix);
    
    void setRealQuaternionPart(U4DQuaternion &uqReal);
    
    void setPureQuaternionPart(U4DQuaternion &uqPure);
    
    U4DDualQuaternion sclerp(U4DDualQuaternion& uToDualQuaternion,float t);
    
    void show();
    
};

}
#endif /* defined(__MathLibrary__U4DDualQuaternion__) */
