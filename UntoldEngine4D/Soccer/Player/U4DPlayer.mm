//
//  U4DPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayer.h"
#include "U4DFoot.h"
#include "CommonProtocols.h"
#include "U4DBall.h"
#include "U4DGameConfigs.h"

#include "U4DPlayerStateManager.h"
#include "U4DPlayerStateInterface.h"

#include "U4DPlayerStateIdle.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateShooting.h"

namespace U4DEngine{

    U4DPlayer::U4DPlayer():dribblingDirection(0.0,0.0,-1.0),dribblingDirectionAccumulator(0.0, 0.0, 0.0),shootBall(false){
        
    }

    U4DPlayer::~U4DPlayer(){
        delete kineticAction;
        delete runningAnimation;
        
    }

    //init method. It loads all the rendering information among other things.
    bool U4DPlayer::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            stateManager=new U4DPlayerStateManager(this);
            
            animationManager=new U4DEngine::U4DAnimationManager();

            kineticAction=new U4DEngine::U4DDynamicAction(this);

            kineticAction->enableKineticsBehavior();

            //kineticAction->enableCollisionBehavior();
            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
            kineticAction->setGravity(zero);
            
            runningAnimation = new U4DEngine::U4DAnimation(this);

            if(loadAnimationToModel(runningAnimation, "running")){

            }
            
            shootingAnimation = new U4DEngine::U4DAnimation(this);

            if(loadAnimationToModel(shootingAnimation, "shooting")){
                shootingAnimation->setPlayContinuousLoop(false);
            }
            
            idleAnimation = new U4DEngine::U4DAnimation(this);

            if(loadAnimationToModel(idleAnimation, "idle")){

            }
            
            loadRenderingInformation();
            
            
            
            return true;
        
        }
        
        return false;
    }

    void U4DPlayer::update(double dt){
        
        stateManager->update(dt);

    }

    void U4DPlayer::changeState(U4DPlayerStateInterface* uState){
        
        stateManager->changeState(uState);
        

    }

    U4DPlayerStateInterface *U4DPlayer::getCurrentState(){
        return stateManager->getCurrentState();
    }

    void U4DPlayer::setFoot(U4DFoot *uFoot){
        
        foot=uFoot;

        addChild(foot);
        
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;
        //original toe.R
        //2. Get the bone rest pose space
        if(getBoneRestPose("RightFoot",m)){

            //3. Apply space to gun
            foot->setLocalSpace(m);
            
        }
    }

    void U4DPlayer::setEnableShooting(bool uValue){
        shootBall=uValue;
    }

    void U4DPlayer::updateFootSpaceWithAnimation(U4DAnimation *uAnimation){
        
        if (foot!=nullptr) {
            
            //declare matrix for the gun space
            U4DEngine::U4DMatrix4n m;
            //original is toe.R
            //2. Get the bone animation "runningAnimation" pose space
            if(getBoneAnimationPose("RightFoot",uAnimation,m)){
     
                //3. Apply space to gun
                foot->setLocalSpace(m);
                
            }
            
        }
        
    }


    void U4DPlayer::applyForce(float uFinalVelocity, double dt){
        
        //force =m*(vf-vi)/dt
        
        //get the force direction and normalize
        dribblingDirection.normalize();
        
        //get mass
        float mass=kineticAction->getMass();
        
        //calculate force
        U4DEngine::U4DVector3n force=(dribblingDirection*uFinalVelocity*mass)/dt;
        
        //apply force to the character
        kineticAction->addForce(force);
        
        //set initial velocity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        kineticAction->setVelocity(zero);
        
    }

    void U4DPlayer::applyVelocity(U4DVector3n &uFinalVelocity, double dt){
        
        //force=m*(vf-vi)/dt
        
        //get mass
        float mass=kineticAction->getMass();
        
        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.85;
        
        forceMotionAccumulator=forceMotionAccumulator*biasMotionAccumulator+uFinalVelocity*(1.0-biasMotionAccumulator);
        
        //calculate force
        U4DEngine::U4DVector3n force=(forceMotionAccumulator*mass)/dt;
        
        //apply force
        kineticAction->addForce(force);
        
        //set initial velocity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        kineticAction->setVelocity(zero);
        
    }

    void U4DPlayer::setViewDirection(U4DVector3n &uViewDirection){
        
        //declare an up vector
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
        
        float biasMotionAccumulator=0.95;
        
        motionAccumulator=motionAccumulator*biasMotionAccumulator+uViewDirection*(1.0-biasMotionAccumulator);
        
        motionAccumulator.normalize();
        
        U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
        
        U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
        
        //transform the upvector
        upVector=m*upVector;
        
        U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
        
        float angle=motionAccumulator.angle(viewDir);
        
        if(motionAccumulator.dot(posDir)>0.0){
            
            angle*=-1.0;
            
        }
        
        U4DEngine::U4DQuaternion q(angle,upVector);
        
        rotateTo(q);
        
    }

    void U4DPlayer::setMoveDirection(U4DVector3n &uMoveDirection){
        
        U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
        
        uMoveDirection.normalize();

        //Get entity forward vector for the player
        U4DEngine::U4DVector3n v=getViewInDirection();

        v.normalize();
        
        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=gameConfigs->getParameterForKey("biasMoveMotion");
        
        motionAccumulator=motionAccumulator*biasMotionAccumulator+uMoveDirection*(1.0-biasMotionAccumulator);
        
        motionAccumulator.normalize();

        //set an up-vector
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

        U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();

        //transform the up vector
        upVector=m*upVector;

        U4DEngine::U4DVector3n posDir=v.cross(upVector);

        //Get the angle between the analog joystick direction and the view direction
        float angle=v.angle(motionAccumulator);
        
        //if the dot product between the joystick-direction and the positive direction is less than zero, flip the angle
        if(motionAccumulator.dot(posDir)>0.0){
            angle*=-1.0;
        }
        
        //create a quaternion between the angle and the upvector
        U4DEngine::U4DQuaternion newOrientation(angle,upVector);

        //Get current orientation of the player
        U4DEngine::U4DQuaternion modelOrientation=getAbsoluteSpaceOrientation();

        //create slerp interpolation
        U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation, 1.0);

        //rotate the character
        rotateBy(p);

    }

    void U4DPlayer::setDribblingDirection(U4DVector3n &uDribblingDirection){
        
            U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
            uDribblingDirection.normalize();
            
            float t=gameConfigs->getParameterForKey("dribblingDirectionSlerpValue");
            //smooth out the motion of the camera by using a Recency Weighted Average.
            //The RWA keeps an average of the last few values, with more recent values being more
            //significant. The bias parameter controls how much significance is given to previous values.
            //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
            //A bias of 1 ignores the new value altogether.
            float biasMotionAccumulator=0.95;
            
            dribblingDirectionAccumulator=dribblingDirectionAccumulator*biasMotionAccumulator+uDribblingDirection*(1.0-biasMotionAccumulator);
            
            dribblingDirectionAccumulator.normalize();

            dribblingDirection=dribblingDirection*t+dribblingDirectionAccumulator*(1.0-t);
        
    }

}
