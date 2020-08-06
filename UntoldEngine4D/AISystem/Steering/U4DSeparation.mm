//
//  U4DSeparation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSeparation.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {

U4DSeparation::U4DSeparation():desiredSeparation(5.0){
        
    }

    U4DSeparation::~U4DSeparation(){
        
    }


    U4DVector3n U4DSeparation::getSteering(U4DDynamicModel *uPursuer, std::vector<U4DDynamicModel*> uNeighborsContainer){
        
        U4DVector3n avgDesiredVelocity;
        
        U4DVector3n desiredVelocity;
        
        int count=0;
        
        for (const auto &n:uNeighborsContainer) {

            //distace to neigbhors
            float d=(uPursuer->getAbsolutePosition()-n->getAbsolutePosition()).magnitude();
            
            if((n!=uPursuer)&&(d<desiredSeparation)){
                
                desiredVelocity=n->getAbsolutePosition()-uPursuer->getAbsolutePosition();
                
                //normalize the velocity. we just want the direction
                desiredVelocity.normalize();
                
                avgDesiredVelocity+=desiredVelocity;
                
                count++;
                
            }
        }
        
        if(count>0){
            
            //compute average desired velocity
            avgDesiredVelocity/=count;
            
            //you want to steer in the opposite direction
            avgDesiredVelocity*=-1.0;
            
            //set the speed
            avgDesiredVelocity*=maxSpeed;
            
            return avgDesiredVelocity;
            
        }
        
        return U4DVector3n(0.0,0.0,0.0);
        
    }

}
