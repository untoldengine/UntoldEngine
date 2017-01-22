//
//  U4DParticleData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleData_hpp
#define U4DParticleData_hpp

#include <stdio.h>
#include "U4DVector3n.h"
#include "U4DIndex.h"
#include <vector>

namespace U4DEngine {
    
    class U4DParticleData {
        
    private:
        
    public:
        
        std::vector<U4DVector3n> verticesContainer;
        
        std::vector<U4DIndex> indexContainer;
        
        std::vector<U4DVector3n> velocityContainer;
        
        std::vector<float> startTimeContainer;
        
        U4DParticleData();
        
        ~U4DParticleData();
        
        void addVerticesDataToContainer(U4DVector3n& uData);
        
        void addIndexDataToContainer(U4DIndex& uData);
        
        std::vector<U4DVector3n> getVerticesDataFromContainer();
        
        void addVelocityDataToContainer(U4DVector3n& uData);
        
        std::vector<U4DVector3n> getVelocityDataFromContainer();
        
        void addStartTimeDataToContainer(float &uData);
        
        std::vector<float> getStartTimeDataFromContainer();
        
    };
    
}


#endif /* U4DParticleData_hpp */
