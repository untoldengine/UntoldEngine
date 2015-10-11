//
//  U4DStaticModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DStaticModel.h"

namespace U4DEngine {
    
    #pragma mark-mass
    //set mass of object
    void U4DStaticModel::setMass(float uMass){
        
        
        massProperties.mass=uMass;
        
        
    }

    float U4DStaticModel::getMass()const{
        
        return massProperties.mass;
    }


    void U4DStaticModel::setCenterOfMass(U4DVector3n& uCenterOfMass){
        
        massProperties.centerOfMass=uCenterOfMass;
        
        //setVertexDistanceFromCenterOfMass();
        
    }

    U4DVector3n U4DStaticModel::getCenterOfMass(){
        
        return massProperties.centerOfMass;
        
    }



    #pragma mark-coefficient of Restitution
    //coefficient of restitution
    void U4DStaticModel::setCoefficientOfRestitution(float uValue){


     if (uValue>1.0) {
         coefficientOfRestitution=1.0;  //coefficient can't be greater than 1
     }else{
         coefficientOfRestitution=uValue;
     }

    }

    float U4DStaticModel::getCoefficientOfRestitution(){

     return coefficientOfRestitution;
    }

    #pragma mark-inertia tensor
    //set and get the intertia tensor
     
     
    void U4DStaticModel::setInertiaTensor(float uRadius){

    U4DMatrix3n tensor;

    //	0	3	6
    //	1	4	7
    //	2	5	8



    }

    void U4DStaticModel::setInertiaTensor(float uX, float uY, float uZ){
        
        U4DMatrix3n tensor;
        
        //	0	3	6
        //	1	4	7
        //	2	5	8
        
        float Ixx=(uY*uY+uZ*uZ)*massProperties.mass/12.0;
        float Iyy=(uX*uX+uZ*uZ)*massProperties.mass/12.0;
        float Izz=(uX*uX+uY*uY)*massProperties.mass/12.0;
        
        float Ixy=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.y);
        float Ixz=massProperties.mass*(massProperties.centerOfMass.x*massProperties.centerOfMass.z);
        float Iyz=massProperties.mass*(massProperties.centerOfMass.y*massProperties.centerOfMass.z);
        
        tensor.matrixData[0]=Ixx;
        tensor.matrixData[4]=Iyy;
        tensor.matrixData[8]=Izz;
        
        tensor.matrixData[3]=-Ixy;
        tensor.matrixData[6]=-Ixz;
        tensor.matrixData[7]=Iyz;
        
        tensor.matrixData[1]=-Ixy;
        tensor.matrixData[2]=-Ixz;
        tensor.matrixData[5]=-Iyz;
        
        
        massProperties.momentOfInertiaTensor=tensor;
        massProperties.inverseMomentOfInertiaTensor=tensor.inverse();
    }


    U4DMatrix3n U4DStaticModel::getMomentOfInertiaTensor(){

    return massProperties.momentOfInertiaTensor;
     
    }

    U4DMatrix3n U4DStaticModel::getInverseMomentOfInertiaTensor(){

    return massProperties.inverseMomentOfInertiaTensor;

    }


    void U4DStaticModel::integralTermsForTensor(float w0,float w1,float w2,float &f1,float &f2, float &f3,float &g0,float &g1,float &g2){

    float temp0=w0+w1;
    f1=temp0+w2;

    float temp1=w0*w0;

    float temp2=temp1+w1*temp0;

    f2=temp2+w2*f1;

    f3=w0*temp1+w1*temp2+w2*f2;

    g0=f2+w0*(f1+w0);
    g1=f2+w1*(f1+w1);
    g2=f2+w2*(f1+w2);


    }

    /*
    void U4DStaticModel::setVertexDistanceFromCenterOfMass(){
        
        //clear the center of mass distance from vertices
        massProperties.vertexDistanceFromCenterOfMass.clear();
        
        std::vector<U4DVector3n> vertices=narrowPhaseBoundingVolume->getVerticesInConvexPolygon();
       
        for (int i=0; i<vertices.size(); i++) {
            
            U4DVector3n distance=massProperties.centerOfMass-vertices.at(i);
        
            massProperties.vertexDistanceFromCenterOfMass.push_back(distance);
            
        }
       
    }
     
     */
    
    void U4DStaticModel::applyCollision(bool uValue){
        
        affectedByCollision=uValue;
    }
    
    
    bool U4DStaticModel::isCollisionApplied(){
        
        return affectedByCollision;
        
    }
    
    
}
