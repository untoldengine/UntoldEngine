//
//  U4DBall.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DBall.h"
#include "U4DNumerical.h"
#include "CommonProtocols.h"

#include "U4DGameConfigs.h"
#include "U4DRay.h"
#include "U4DRayCast.h"

#include "U4DBallStateInterface.h"
#include "U4DBallStateManager.h"
#include "U4DBallStateIdle.h"
#include "U4DBallStateFalling.h"

namespace U4DEngine {
    
    U4DBall* U4DBall::instance=0;

    U4DBall::U4DBall():kickMagnitude(0.0),motionAccumulator(0.0,0.0,0.0),aiScored(false),obstacle(nullptr){
        
    }

    U4DBall::~U4DBall(){
        
        delete stateManager;
        
    }

    U4DBall* U4DBall::sharedInstance(){
        
        if (instance==0) {
            
            instance=new U4DBall();
            
        }
        
        return instance;
    }

    //init method. It loads all the rendering information among other things.
    bool U4DBall::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            stateManager=new U4DBallStateManager(this);
            
            kineticAction=new U4DDynamicAction(this);
            
            kineticAction->initMass(5.0);
            
//            U4DVector2n dragCoeff(0.0,0.0);
//            kineticAction->setDragCoefficient(dragCoeff);
            //enable kinetic behavior
            kineticAction->enableKineticsBehavior();
            
            //set gravity to zero
            U4DVector3n zero(0.0,0.0,0.0);
            kineticAction->setGravity(zero);
            
            //set default view of the character
            U4DVector3n viewDirectionVector(0.0,0.0,1.0);
            setEntityForwardVector(viewDirectionVector);
            
            //enable collision detection
            kineticAction->enableCollisionBehavior();

            //set player as a collision sensor. Meaning only detection is enabled but not the collision response
            kineticAction->setIsCollisionSensor(true);

            //I am of type
            kineticAction->setCollisionFilterCategory(kBall);

            //I collide with type of ball.
            kineticAction->setCollisionFilterMask(kFoot|kOppositePlayer|kGoalSensor);

            //set a tag
            kineticAction->setCollidingTag("ball");
            //kineticAction->setNarrowPhaseBoundingVolumeVisibility(true);
            
            homePosition=getAbsolutePosition();
            
            setClassType("U4DBall");
            
            //send info to the GPU
            loadRenderingInformation();
            
            //initialize the scheduler
            //Create the callback. Notice that you need to provide the name of the class
            obstacleCollisionScheduler=new U4DEngine::U4DCallback<U4DBall>;

            //create the timer
            obstacleCollisionTimer=new U4DEngine::U4DTimer(obstacleCollisionScheduler);

            obstacleCollisionScheduler->scheduleClassWithMethodAndDelay(this, &U4DBall::testIfBallOnPlatform, obstacleCollisionTimer,0.5, true);
            
            obstacleCollisionTimer->setPause(true);
            
            changeState(U4DBallStateIdle::sharedInstance());
            
            return true;
            
        }
        
        return false;
        
    }

    void U4DBall::update(double dt){

        stateManager->update(dt);
        
    }

    U4DEngine::U4DVector3n U4DBall::predictPosition(double dt, float uTimeScale){
        
        float a=-kickMagnitude;
        float vi=kineticAction->getVelocity().magnitude();
        float t=dt*uTimeScale;
        
        float sf=vi*t+(0.5)*(a)*(t*t);

        U4DEngine::U4DVector3n finalPosition=getAbsolutePosition()+kickDirection*sf;
        
        return finalPosition;
        
    }

    float U4DBall::timeToCoverDistance(U4DVector3n &uFinalPosition){
        
        U4DEngine::U4DVector3n velocity=kickDirection*kickMagnitude;
         
        float u=velocity.magnitude();
        
        float distanceToCover=(uFinalPosition-getAbsolutePosition()).magnitude();
        
        float a=kickMagnitude;
        
        float term=u*u+2.0*distanceToCover*a;
        
        if(term<=0) return -1.0;
        
        float v=sqrt(term);
        
        return (v-u)/a;
        
    }

    void U4DBall::setKickBallParameters(float uKickMagnitude,U4DVector3n &uKickDirection){
        
        kickMagnitude=uKickMagnitude;
        kickDirection=uKickDirection;
    }

    void U4DBall::applyForce(float uFinalVelocity, double dt){
        
        //force =m*(vf-vi)/dt
        
        //get the force direction and normalize
        kickDirection.normalize();
        
        //get mass
        float mass=kineticAction->getMass();
        
        //calculate force
        U4DVector3n force=(kickDirection*uFinalVelocity*mass)/dt;
        
        //apply force to the character
        kineticAction->addForce(force);
        
        //set initial velocity to zero
        U4DVector3n zero(0.0,0.0,0.0);
        kineticAction->setVelocity(zero);
        kineticAction->setAngularVelocity(zero);
        
    }

    void U4DBall::applyRoll(float uFinalVelocity, double dt){
        
        //get the force direction and normalize
        kickDirection.normalize();
        
        //get mass
        float mass=kineticAction->getMass();
        
        //calculate force
        U4DVector3n force=(kickDirection*uFinalVelocity*mass)/dt;
        
        //apply moment to ball
        U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
        
        U4DVector3n groundPassMoment=upAxis.cross(force);
        
        kineticAction->addMoment(groundPassMoment);
        
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        kineticAction->setAngularVelocity(zero);
        
    }
    

    void U4DBall::changeState(U4DBallStateInterface* uState){
        
        stateManager->changeState(uState);
    }

    U4DBallStateInterface *U4DBall::getCurrentState(){
        return stateManager->getCurrentState();
    }

    U4DBallStateInterface *U4DBall::getPreviousState(){
        return stateManager->getPreviousState();
    }

    void U4DBall::applyVelocity(U4DVector3n &uFinalVelocity, double dt){

        //force=m*(vf-vi)/dt
        
        //get mass
        float mass=kineticAction->getMass();

        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.2;
        
        motionAccumulator=motionAccumulator*biasMotionAccumulator+uFinalVelocity*(1.0-biasMotionAccumulator);
        
        //calculate force
        U4DVector3n force=(motionAccumulator*mass)/dt;

        //apply force
        kineticAction->addForce(force);
        
        //apply moment to ball
        U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
        
        force*=0.25;
        U4DVector3n moment=upAxis.cross(force);
        
        kineticAction->addMoment(moment);
        
        //set initial velocity to zero
        U4DVector3n zero(0.0,0.0,0.0);
        kineticAction->setVelocity(zero);
        kineticAction->setAngularVelocity(zero);
        
    }

    void U4DBall::decelerate(double dt){
        
        //awake the ball
        kineticAction->setAwake(true);

        U4DVector3n ballVelocity=kineticAction->getVelocity();

        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all. In this case, full stop.
        //A bias of 1 ignores the new value altogether. In this case, no deceleration.
        float biasMotionAccumulator=0.95;

        motionAccumulator=motionAccumulator*biasMotionAccumulator+ballVelocity*(1.0-biasMotionAccumulator);

        U4DVector3n force=(motionAccumulator*kineticAction->getMass())/dt;

        kineticAction->addForce(force);

       //apply moment to ball
        U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);

        force*=0.25;

        U4DVector3n moment=upAxis.cross(force);

        kineticAction->addMoment(moment);

        //zero out the velocities
        U4DVector3n initialVelocity(0.0,0.0,0.0);

        kineticAction->setVelocity(initialVelocity);
        kineticAction->setAngularVelocity(initialVelocity);
        
    }

    void U4DBall::insideGoalPost(U4DGoalPost *uGoalPost){
        goalPostBallIsIn=uGoalPost;
    }

    U4DGoalPost *U4DBall::getBallInsideGoalPost(){
        return goalPostBallIsIn;
    }

    void U4DBall::setIntersectingObstacle(U4DModel *uObstacle){
        obstacle=uObstacle;
    }

    bool U4DBall::testObstacleIntersection(){
        
        bool mapIntersection=false;
        
        if(obstacle!=nullptr){
            
            //create a ray cast
            U4DRayCast rayCast;
            U4DTriangle hitTriangle;
            U4DPoint3n intPoint;
            float intTime=0.0;
            
            //create a ray
            U4DPoint3n playerPosition=getAbsolutePosition().toPoint();
            U4DVector3n rayDirection=U4DVector3n(0.0,-1.0,0.0);
            
            U4DRay ray(playerPosition,rayDirection);
            
            if(rayCast.hit(ray,obstacle,hitTriangle,intPoint, intTime)){
                
                    if(intTime<3.0){
                        mapIntersection=true;
                    }

            }
            
        }

        return mapIntersection;
        
    }

    void U4DBall::testIfBallOnPlatform(){
        
        if(!testObstacleIntersection() && obstacle!=nullptr){

            changeState(U4DBallStateFalling::sharedInstance());
        }
        
    }

    void U4DBall::setViewDirection(U4DVector3n &uViewDirection){
        
        //declare an up vector
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
        
        U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
        
        //transform the upvector
        upVector=m*upVector;
        
        U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
        
        float angle=uViewDirection.angle(viewDir);
        
        if(uViewDirection.dot(posDir)>0.0){
            
            angle*=-1.0;
            
        }
        
        U4DEngine::U4DQuaternion q(angle,upVector);
        
        rotateTo(q);
        
        
    }

}
