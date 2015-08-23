//
//  U4DStaticModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DStaticModel__
#define __UntoldEngine__U4DStaticModel__

#include <iostream>
#include "U4DModel.h"

namespace U4DEngine {
    
typedef struct{
    
    float mass;
    U4DVector3n centerOfMass;
    U4DMatrix3n momentOfInertiaTensor;
    U4DMatrix3n inverseMomentOfInertiaTensor;
    std::vector<U4DVector3n> vertexDistanceFromCenterOfMass;
    
}MassProperties;

typedef struct{
    
    U4DVector3n contactPoint; //contact points (e.g. against plane, OBB, etc)
    U4DVector3n forceOnContactPoint;
    U4DVector3n lineOfAction;
    
}CollisionInformation;

typedef struct{
    
    CollisionInformation collisionInformation;
    bool collided; //did the model collided
    float penetrationPoint;
    
}CollisionProperties;
}


namespace U4DEngine {
    
class U4DStaticModel:public U4DModel{
    
private:
    
protected:
    
public:
    
    U4DStaticModel(){
        
        massProperties.mass=1.0;
        
        collisionProperties.collided=false;
        
        U4DVector3n centerOfMass(0.0,0.0,0.0);
        
        setCenterOfMass(centerOfMass);
        
        coefficientOfRestitution=1.0;
        
        setInertiaTensor(1.0,1.0,1.0);
        
        
    
    };
    
    ~U4DStaticModel(){};
    
    U4DStaticModel(const U4DStaticModel& value){};
    
    U4DStaticModel& operator=(const U4DStaticModel& value){return *this;};
    
    MassProperties massProperties;
    
    CollisionProperties collisionProperties;
    
    float coefficientOfRestitution;
 
    void setMass(float uMass);
    
    float getMass()const;
    
    void setCenterOfMass(U4DVector3n& uCenterOfMass);
    
    U4DVector3n getCenterOfMass();
    
    void setCoefficientOfRestitution(float uValue);
    
    float getCoefficientOfRestitution();
    
    void setInertiaTensor(float uRadius);
    
    void setInertiaTensor(float uLength, float uWidth, float uHeight);
    
    U4DMatrix3n getMomentOfInertiaTensor();
    
    U4DMatrix3n getInverseMomentOfInertiaTensor();
    
    void integralTermsForTensor(float w0,float w1,float w2,float &f1,float &f2, float &f3,float &g0,float &g1,float &g2);
    
    void setVertexDistanceFromCenterOfMass();
};
    
}

#endif /* defined(__UntoldEngine__U4DStaticModel__) */
