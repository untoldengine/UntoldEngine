//
//  Ball.cpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Ball.h"
#include "U4DNumerical.h"
#include "UserCommonProtocols.h"

Ball* Ball::instance=0;

Ball::Ball():kickMagnitude(0.0),motionAccumulator(0.0,0.0,0.0){
    
}

Ball::~Ball(){
    
}

Ball* Ball::sharedInstance(){
    
    if (instance==0) {
        
        instance=new Ball();
        
    }
    
    return instance;
}

//init method. It loads all the rendering information among other things.
bool Ball::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //set enable shadows
        setEnableShadow(true);
        
        setNormalMapTexture("Ball_Normal_Map.png");
        
        initInertiaTensorType(U4DEngine::sphericalInertia);
        
        initMass(5.0);
        U4DEngine::U4DVector2n dragCoeff(0.0,0.0);
        setDragCoefficient(dragCoeff);
        //enable kinetic behavior
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //set default view of the character
        U4DEngine::U4DVector3n viewDirectionVector(0.0,0.0,1.0);
        setEntityForwardVector(viewDirectionVector);
        
        //enable collision detection
        enableCollisionBehavior();
        
        //set player as a collision sensor. Meaning only detection is enabled but not the collision response
        setIsCollisionSensor(true);
        
        //I am of type
        setCollisionFilterCategory(kBall);
        
        //I collide with type of ball.
        setCollisionFilterMask(kFoot);
        
        //set a tag
        setCollidingTag("ball");
        
        setState(idle);
        
        //send info to the GPU
        loadRenderingInformation();
        
        return true;
        
    }
    
    return false;
    
}

void Ball::update(double dt){
    
    setAwake(true);
    
    //check if collision is happening
    
    if(state==rolling){
        
       // applyRoll(2.0,dt);

    }else if (state==stopped){

        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        setVelocity(zero);
        setAngularVelocity(zero);
        
    }else if(state==kicked){
        
        U4DEngine::U4DVector3n dir=kickDirection*kickMagnitude;
        applyVelocity(dir, dt);
        
    }else if(state==decelerating){
        
        //remove all velocities from the character
        decelerate(dt);
        
    }
    
//    if (getModelHasCollided()) {
//
//        applyForce(kickMagnitude, dt);
//        changeState(rolling);
//    }
    if(state==kicked && !getModelHasCollided()){
        changeState(decelerating);
    }
    
}

U4DEngine::U4DVector3n Ball::predictPosition(double dt, float uTimeScale){
    
    float a=-kickMagnitude;
    float vi=getVelocity().magnitude();
    float t=dt*uTimeScale;
    
    float sf=vi*t+(0.5)*(a)*(t*t);

    U4DEngine::U4DVector3n finalPosition=getAbsolutePosition()+kickDirection*sf;
    
    return finalPosition;
    
}

float Ball::timeToCoverDistance(U4DEngine::U4DVector3n &uFinalPosition){
    
    U4DEngine::U4DVector3n velocity=kickDirection*kickMagnitude;
     
    float u=velocity.magnitude();
    
    float distanceToCover=(uFinalPosition-getAbsolutePosition()).magnitude();
    
    float a=kickMagnitude;
    
    float term=u*u+2.0*distanceToCover*a;
    
    if(term<=0) return -1.0;
    
    float v=sqrt(term);
    
    return (v-u)/a;
    
}

void Ball::setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection){
    
    kickMagnitude=uKickMagnitude;
    kickDirection=uKickDirection;
}

void Ball::applyForce(float uFinalVelocity, double dt){
    
    //force =m*(vf-vi)/dt
    
    //get the force direction and normalize
    kickDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(kickDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
    
}

void Ball::applyRoll(float uFinalVelocity, double dt){
    
    //get the force direction and normalize
    kickDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(kickDirection*uFinalVelocity*mass)/dt;
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(force);
    
    addMoment(groundPassMoment);
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    setAngularVelocity(zero);
    
}

void Ball::setState(int uState){
    state=uState;
}

int Ball::getState(){
    return state;
}

int Ball::getPreviousState(){
    return previousState;
}

void Ball::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    
    switch (uState) {
         
        case stopped:
            //nothing happens
            
            break;
        
        
        case rolling:
            
            
            break;
        
        case decelerating:

            break;
            
        default:
            break;
    }
}

void Ball::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){

    //force=m*(vf-vi)/dt
    
    //get mass
    float mass=getMass();

    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=0.4;
    
    motionAccumulator=motionAccumulator*biasMotionAccumulator+uFinalVelocity*(1.0-biasMotionAccumulator);
    
    //calculate force
    U4DEngine::U4DVector3n force=(motionAccumulator*mass)/dt;

    //apply force
    addForce(force);
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
    
    force*=0.25;
    
    U4DEngine::U4DVector3n moment=upAxis.cross(force);
    
    addMoment(moment);

    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);

}

void Ball::decelerate(double dt){
    
    //awake the ball
    setAwake(true);

    U4DEngine::U4DVector3n ballVelocity=getVelocity();

    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all. In this case, full stop.
    //A bias of 1 ignores the new value altogether. In this case, no deceleration.
    float biasMotionAccumulator=0.95;

    motionAccumulator=motionAccumulator*biasMotionAccumulator+ballVelocity*(1.0-biasMotionAccumulator);
    
    U4DEngine::U4DVector3n force=(motionAccumulator*getMass())/dt;
    
    addForce(force);

   //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
    
    force*=0.25;
    
    U4DEngine::U4DVector3n moment=upAxis.cross(force);
    
    addMoment(moment);

    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);

    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}

//
//void Ball::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
//
//    //declare an up vector
//    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
//
//    float biasMotionAccumulator=0.9;
//
//    motionAccumulator=motionAccumulator*biasMotionAccumulator+uViewDirection*(1.0-biasMotionAccumulator);
//
//    motionAccumulator.normalize();
//
//    U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
//
//    U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
//
//    //transform the upvector
//    upVector=m*upVector;
//
//    U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
//
//    float angle=motionAccumulator.angle(viewDir);
//
//    if(motionAccumulator.dot(posDir)>0.0){
//
//        angle*=-1.0;
//
//    }
//
//    U4DEngine::U4DQuaternion q(angle,upVector);
//
//    rotateTo(q);
//
//}
