//
//  U4DFollowPath.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFollowPath_hpp
#define U4DFollowPath_hpp

#include <stdio.h>
#include <vector>
#include <float.h>
#include "U4DSeek.h"
#include "U4DVector3n.h"
#include "U4DPoint3n.h"
#include "U4DSegment.h"

namespace U4DEngine {
    
    /**
     @ingroup artificialintelligence
     @brief The U4DFollowPath class implements AI steering Path Following behavior
     */
    class U4DFollowPath:public U4DSeek {
        
    private:
        
        /**
         @brief holds the time in the future to predict the position
         */
        float predictTime;
        
        /**
         @brief holds the distance along the path to generate the target position
         */
        float pathOffset;
        
        /**
         @brief radius of path
         */
        float pathRadius;
        
        /**
         @brief index in the path(segment) vector the model is currently following
         */
        int currentPathIndex;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DFollowPath();
        
        /**
         @brief class destructor
         */
        ~U4DFollowPath();
        
        /**
         @brief Computes the velociry for steering along the provided path
         
         @param uDynamicModel 3D model represented as the pursuer
         @param uPathContainer segment vector representing the path the pursuer must follow
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicModel *uDynamicModel, std::vector<U4DSegment> &uPathContainer);
        
        /**
         @brief sets the time in the future to predict the position
         
         @param uPredictTime time value
         */
        void setPredictTime(float uPredictTime);
        
        /**
         @brief set the distance along the path to generate the target position
         
         @param uPathOffset path offset
         */
        void setPathOffset(float uPathOffset);
        
        /**
         @brief set the path radius
         
         @param uPathRadius radius of path
         */
        void setPathRadius(float uPathRadius);
        
        /**
         @brief gets the current path the pursuer is following
         
         @return index in the path(segment) vector
         */
        int getCurrentPathIndex();
        
    };
    
}

#endif /* U4DFollowPath_hpp */
