//
//  U4DDynamicModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DDynamicModel__
#define __UntoldEngine__U4DDynamicModel__

#include <iostream>
#include <vector>
#include "U4DStaticModel.h"
#include "U4DVector3n.h"
#include "U4DPlane.h"

namespace U4DEngine {

class U4DBodyForceGenerator;

}

namespace U4DEngine {
/**
 *  Class in charge of all movable objects in the game such as characters, bullets, etc
 */
class U4DDynamicModel:public U4DStaticModel{
    
private:
    
protected:
    
    bool affectedByPhysics;
    
    /**
     *  Velocity vector of object
     */
    U4DVector3n velocity;
    
    /**
     *  Acceleration vector of object
     */
    U4DVector3n acceleration;
    
    /**
     *  Force vector of object
     */
    U4DVector3n force;
    
    /**
     *  Angular velocity vector of object
     */
    U4DVector3n angularVelocity;
    
    /**
     *  Moment vector of object
     */
    U4DVector3n moment;
    
    /**
     *  is object awake? used for collision
     */
    bool isAwake;
    
    /**
     *  Motion magnitude
     */
    float motion;
    
public:
    
    /**
     *  Constructor
     */
    U4DDynamicModel();
    
    /**
     *  Destructor
     */
    ~U4DDynamicModel();
    
    /**
     *  Copy Constructor
     */
    U4DDynamicModel(const U4DDynamicModel& value);
    
    /**
     *  Copy Constructor
     */
    U4DDynamicModel& operator=(const U4DDynamicModel& value);
    
    
    /**
     *  Clear forces acted on the body
     */
    void clearForce();
    
    /**
     *  Add forces acted on the body
     *
     *  @param uForce Force to add to the body
     */
    void addForce(U4DVector3n& uForce);
    
    /**
     *  Get current Sum of forces vector acting on the body
     *
     *  @return Sum forces acted on the body
     */
    U4DVector3n getForce();
    
    /**
     *  Get Sum of moment vector acting on the body
     *
     *  @return Sum moment vector acting on the body
     */
    U4DVector3n getMoment();
    
    /**
     *  Add moments acting on the body
     *
     *  @param uMoment moment vector to add to the body
     */
    void addMoment(U4DVector3n& uMoment);
    
    /**
     *  Clear all moment forces
     */
    void clearMoment();

    /**
     *  Get current velocity of object
     *
     *  @return velocity vector of object
     */
    U4DVector3n getVelocity() const;
    
    /**
     *  Set velocity of object
     *
     *  @param uVelocity velocity vector of object
     */
    void setVelocity(U4DVector3n &uVelocity);
    
    /**
     *  Get the angular velocity of the body
     *
     *  @return angular velocity vector of body
     */
    U4DVector3n getAngularVelocity();
    
    /**
     *  Set body angular velocity vector
     *
     *  @param uAngularVelocity angular velocity vector
     */
    void setAngularVelocity(U4DVector3n& uAngularVelocity);
    
    /**
     *  Set if body is awake
     *
     *  @param uValue is awake?
     */
    void setAwake(bool uValue);
    
    /**
     *  Get if body is awake
     *
     *  @return is body awake?
     */
    bool getAwake();
    
    /**
     *  Set motion magnitude of bode
     *
     *  @param uValue magnitude of motion
     */
    void setMotion(float uValue, float dt);
    
    /**
     *  Get motion magnitude of body
     *
     *  @return magnitude of motion
     */
    float getMotion();
    
    void applyPhysics(bool uValue);
    
    bool isPhysicsApplied();
    
};

}

#endif /* defined(__UntoldEngine__U4DDynamicModel__) */
