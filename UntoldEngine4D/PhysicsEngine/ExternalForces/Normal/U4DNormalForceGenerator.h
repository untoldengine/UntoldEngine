//
//  U4DNormalForceGenerator.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/13/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#ifndef U4DNormalForceGenerator_hpp
#define U4DNormalForceGenerator_hpp

#include <stdio.h>
#include "U4DBodyForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    class U4DNormalForceGenerator:public U4DBodyForceGenerator{
        
    private:
        
        U4DVector3n normalForce;
        
    public:
        
        U4DNormalForceGenerator();
        
        ~U4DNormalForceGenerator();
        
        void updateForce(U4DDynamicModel *uModel, float dt);
        
        void setNormalForce(U4DVector3n& uNormalForce);
        
        U4DVector3n getNormalForce();
        
        
    };
    
}




#endif /* U4DNormalForceGenerator_hpp */
