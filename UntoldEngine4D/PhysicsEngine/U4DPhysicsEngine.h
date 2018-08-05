//
//  BodyForceRegistry.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DPhysicsEngine__
#define __UntoldEngine__U4DPhysicsEngine__

#include <iostream>
#include <vector>

#include "U4DDynamicModel.h"
#include "U4DBodyForceGenerator.h"
#include "U4DIntegrator.h"
#include "U4DGravityForceGenerator.h"
#include "U4DDragForceGenerator.h"
#include "U4DRestingForcesGenerator.h"


namespace U4DEngine {

    /**
     @brief The U4DPhysicsEngine class is in charge of implemeting the physics engine operations
     */
    class U4DPhysicsEngine{
      
    private:
       
        /**
         @brief Object in charge of integrating the equation of motion
         */
        U4DIntegrator *integrator;
        
        /**
         @brief Object in charge of simulating the force of gravity
         */
        U4DGravityForceGenerator gravityForce;
        
        /**
         @brief Object in charge of simulating the drag force
         */
        U4DDragForceGenerator dragForce;
        
        /**
         @brief Object in charge of simulating resting forces
         */
        U4DRestingForcesGenerator restingForces;
        
    protected:

        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DPhysicsEngine();
        
        /**
         @brief Destructor for the class
         */
        ~U4DPhysicsEngine();
        
        /**
         @brief Method which updates all physics forces
         
         @param uModel 3D model entity
         @param dt     Time-step value
         */
        void updatePhysicForces(U4DDynamicModel *uModel,float dt);
        
        /**
         @brief Method which sets the integrator
         
         @param uIntegrator Pointer to the integrator to use
         */
        void setIntegrator(U4DIntegrator *uIntegrator);
        
        /**
         @brief Method which integrates the equation of motion
         
         @param uModel 3D model entity
         @param dt     Time-step value
         */
        void integrate(U4DDynamicModel *uModel,float dt);
        
        /**
         @brief Method which updates the state of the physics engine
         
         @param dt Time-step value
         */
        void update(float dt);
        
        
    };

}

#endif /* defined(__UntoldEngine__U4DPhysicsEngine__) */
