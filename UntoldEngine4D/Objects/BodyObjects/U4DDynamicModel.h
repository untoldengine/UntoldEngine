//
//  U4DDynamicModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DDynamicModel__
#define __UntoldEngine__U4DDynamicModel__

#include <iostream>
#include <vector>
#include "U4DStaticModel.h"
#include "U4DVector3n.h"
#include "U4DPlane.h"
#include "U4DParticleData.h"

namespace U4DEngine {

    class U4DBodyForceGenerator;
    class U4DEntityManager;
    
}

namespace U4DEngine {

/**
 @ingroup gameobjects
 @brief The U4DDynamicModel class represents a 3D dynamic model entity
 */

class U4DDynamicModel:public U4DStaticModel{
    
private:
    
protected:

    /**
     @brief Velocity of 3D model
     */
    U4DVector3n velocity;
    
    /**
     @brief Acceleration of 3D model
     */
    U4DVector3n acceleration;

    /**
     @brief Force of 3D model
     */
    U4DVector3n force;

    /**
     @brief Angular velocity of 3D model
     */
    U4DVector3n angularVelocity;
 
    /**
     @brief Moment of 3D model
     */
    U4DVector3n moment;
    
    /**
     @brief The axis of rotation of the 3D model
     */
    U4DVector3n axisOfRotation;
    
    /**
     @brief Gravity force of the 3D model
     */
    U4DVector3n gravity;
    
    /**
     @brief Drag force coefficient of the 3D model
     */
    U4DVector2n dragCoefficient;

    /**
     @brief Kinetic energy of the model
     */
    float modelKineticEnergy;

    /**
     @brief Time that the 3D model will impact with another object
     */
    float timeOfImpact;

    /**
     @brief Equilibrium state of the model upon collision
     */
    bool equilibrium;
    
    /**
     @brief Variable representing if kinetics behaviour enabled. i.e., if forces can act upon the 3D model
     */
    bool kineticsEnabled;
    
    /**
     @brief Variable representing if the model is awake
     */
    bool isAwake;
    
public:
    
    /**
     @brief Constructor for the class
     */
    U4DDynamicModel();
    
    /**
     @brief Destructor for the class
     */
    ~U4DDynamicModel();
    
    /**
     @brief Copy constructor
     */
    U4DDynamicModel(const U4DDynamicModel& value);
    
    /**
     @brief Copy constructor
     */
    U4DDynamicModel& operator=(const U4DDynamicModel& value);
    
    //Add operations

    /**
     @brief Method which adds all the forces acting on the model
     
     @param uForce 3D vector representing a force
     */
    void addForce(U4DVector3n& uForce);
    
    /**
     @brief Method which adds all the moments acting on the model
     
     @param uMoment 3D vector representing a moment
     */
    void addMoment(U4DVector3n& uMoment);
    
    //Behavior operations
    
    /**
     @brief Method which enables kinetics behavior on the 3D model.
     @details It allows forces to act on the 3D model
     */
    void enableKineticsBehavior();
    
    /**
     @brief Method which pauses kinetics behavior on the 3D model
     */
    void pauseKineticsBehavior();
    
    /**
     @brief Method which resumes kinetics behavior on the 3D model
     */
    void resumeKineticsBehavior();
    
    /**
     @brief Method which returns if kinetics behavior are allowed to act on the 3D model
     
     @return Returns true if kinetics behavior are allowed to act on the 3D model
     */
    bool isKineticsBehaviorEnabled();
    
    //Clear operations
    
    /**
     @brief Clears all forces acting on the 3D model
     */
    void clearForce();
    
    /**
     @brief Clears all moments acting on the 3D model
     */
    void clearMoment();
    
    //Set operations
    
    /**
     @brief Method which sets the velocity of the model
     
     @param uVelocity 3D vector representing the velocity of the model
     */
    void setVelocity(U4DVector3n &uVelocity);
    
    /**
     @brief Method which sets the angular velocity of the model
     
     @param uAngularVelocity 3D vector representing the angular velocity of the model
     */
    void setAngularVelocity(U4DVector3n& uAngularVelocity);
    
    /**
     @brief Method which sets the time of impact. i.e., the time the 3D model will collide with another 3D model
     
     @param uTimeOfImpact The time of impact
     */
    void setTimeOfImpact(float uTimeOfImpact);
    
    /**
     @brief Method which sets the axis of rotation for the 3D model
     
     @param uAxisOfRotation 3D vector representing the axis of rotation for the model
     */
    void setAxisOfRotation(U4DVector3n &uAxisOfRotation);
    
    /**
     @brief Method which sets if the 3D model is awake
     
     @param uValue Set to true if the 3D model is awake
     */
    void setAwake(bool uValue);
    
    /**
     @brief Method which sets if the 3D model is in equilibrium
     
     @param uValue Set to true if the 3D model is in equilibrium
     */
    void setEquilibrium(bool uValue);
    
    /**
     @brief Method which sets the gravity force acting on the 3D model
     
     @param uGravity 3D vector representing the gravity force acting on the 3D model
     */
    void setGravity(U4DVector3n& uGravity);
    
    /**
     @brief Method which sets the drag coefficient acting on the 3D model
     
     @param uDragCoefficient 2D vector representing the drag coefficients
     */
    void setDragCoefficient(U4DVector2n& uDragCoefficient);
    
    //Compute operations
    
    /**
     @brief Method which determines the kinetic motion of the model
     
     @param dt time step value
     */
    void computeModelKineticEnergy(float dt);
    
    //Reset operations
    
    /**
     @brief Method which reset the time of impact of the model
     */
    void resetTimeOfImpact();
    
    /**
     @brief Method which resets the gravivy force of the model to its default value. Default gravity is (0.0,-10.0,0.0)
     */
    void resetGravity();
    
    /**
     @brief Method which resets the drag coefficients to its default value. Default drag coefficient is (0.9,0.9)
     */
    void resetDragCoefficient();
    
    //Get operations
    
    /**
     @brief Method which returns commulative forces acting on the model
     
     @return Returns commulative forces acting on the model
     */
    U4DVector3n getForce();
    
    /**
     @brief Method which returns commulative moments acting on the model
     
     @return Returns commulative moments acting on the model
     */
    U4DVector3n getMoment();
    
    /**
     @brief Method which returns the velocity of the model
     
     @return Returns the velocity of the model
     */
    U4DVector3n getVelocity();
    
    /**
     @brief Method which returns the angular velocity of the model
     
     @return Returns the angular velocity of the model
     */
    U4DVector3n getAngularVelocity();
    
    /**
     @brief Method which returns if the 3D model is awake
     
     @return returns true if the 3D model is awake
     */
    bool getAwake();
    
    /**
     @brief Method which returns the kinetic energy of the model
     
     @return Returns the kinetic energy of the model
     */
    float getModelKineticEnergy();
    
    /**
     @brief Method which returns the collision time of impact of the model
     
     @return Returns the time of impact
     */
    float getTimeOfImpact();
    
    /**
     @brief Method which returns the model axis of rotation
     
     @return Returns 3D vector representing the model axis of rotation
     */
    U4DVector3n getAxisOfRotation();
    
    /**
     @brief Method which returns if the model is in equilibrium
     
     @return Returns true if the model is in equilibrium
     */
    bool getEquilibrium();
    
    /**
     @brief Method which returns the gravity force acting on the 3D model
     
     @return Returns a 3D vector representing the gravity force acting on the model
     */
    U4DVector3n getGravity();
    
    /**
     @brief Method which returns the drag coefficients acting on the 3D model
     
     @return Returns a 2D vector representing the drag coefficients acting on the model
     */
    U4DVector2n getDragCoefficient();
    
    /**
     @brief Self load 3D model into the collision engine
     
     @param uEntityManager pointer to the entity manager
     */
    void loadIntoCollisionEngine(U4DEntityManager *uEntityManager);
    
    
    /**
     @brief Self load 3D model into the physics engine

     @param uEntityManager pointer to the entity manager
     @param dt time step
     */
    void loadIntoPhysicsEngine(U4DEntityManager *uEntityManager, float dt);
    
    
    /**
     @brief self load 3d model into the visibility manager

     @param uEntityManager pointer to the entity manager
     */
    void loadIntoVisibilityManager(U4DEntityManager *uEntityManager);
    
    
    /**
     @brief clear collision information, resets time of impact, resets equilibrium, clears collision list
     */
    void cleanUp();
    
};

}

#endif /* defined(__UntoldEngine__U4DDynamicModel__) */
