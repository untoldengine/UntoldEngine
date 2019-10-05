//
//  U4DNavigation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNavigation_hpp
#define U4DNavigation_hpp

#include <stdio.h>
#include <vector>
#include "U4DSegment.h"
#include "U4DVector3n.h"
#include "U4DFollowPath.h"
#include "U4DArrive.h"

namespace U4DEngine {
    
    class U4DNavMesh;
    class U4DPathfinderAStar;
    class U4DDynamicModel;
    
}

namespace U4DEngine {

    /**
     @ingroup artificialintelligence
     @brief The U4DNavigation class determines the path for the 3D model to navigate
     */
    class U4DNavigation {
        
    private:
        
        /**
         @brief pointer to navigation mesh object. This object contains the navigation mesh nodes
         */
        U4DNavMesh *navMesh;
        
        /**
         @brief computed navigation path the 3D model should follow
         */
        std::vector<U4DSegment> path;
        
        /**
         @brief target position
         */
        U4DVector3n targetPosition;
        
        /**
         @brief object representing the followPath steering behavior class. This is used to steer the 3D model along the specified path
         */
        U4DFollowPath followPath;
        
        /**
         @brief object representing the arrive steering behavior class. This is used to steer the 3D model as it arrives to the target destination
         */
        U4DArrive arrive;
        
        /**
         @brief was the path properly computed.
         */
        bool pathComputed;
        
        /**
         @brief stores the last path segment in the path container. Used to switch between the followPath and arrive behaviors
         */
        int lastPathInNavMeshIndex;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DNavigation();
        
        /**
         @brief class destructor
         */
        ~U4DNavigation();
        
        
        /**
         @brief loads the navigation mesh imported from blender

         @param uNavMeshName name of navigation mesh as specified in blender 3D
         @param uBlenderFile name of file
         @return true if the nav mesh was properly loaded
         */
        bool loadNavMesh(const char* uNavMeshName, const char* uBlenderFile);
        
        
        /**
         @brief computes the path using the provided starting and target positions

         @param uDynamicModel 3D model representing the pursuer
         @param uTargetPosition target position
         */
        void computePath(U4DDynamicModel *uDynamicModel, U4DVector3n &uTargetPosition);
        
        /**
         @brief Computes the velocity for steering
         
         @param uDynamicModel 3D model represented as the pursuer
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicModel *uDynamicModel);
        
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
         @brief sets the radius distance to the target where the velocity of the pursuer should come to a stop
         
         @param uTargetRadius radius of circle to stop
         */
        void setTargetRadius(float uTargetRadius);
        
        /**
         @brief sets the radius distance to the target where the pursuer should slow down
         
         @param uSlowRadius radius of circle to slow down
         */
        void setSlowRadius(float uSlowRadius);
        
        /**
         @brief sets the navigation speed for the pursuer
         
         @param uNavigationSpeed navigation speed
         */
        void setNavigationSpeed(float uNavigationSpeed);
        
    };
    
}

#endif /* U4DNavigation_hpp */
