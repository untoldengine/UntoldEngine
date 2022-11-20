//
//  U4DNettingSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/15/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNettingSystem_hpp
#define U4DNettingSystem_hpp

#include <stdio.h>
#include "U4DEntity.h"

namespace U4DEngine {

    class U4DNettingSystem {
        
    private:
        
    public:
        
        U4DNettingSystem();
        
        ~U4DNettingSystem();
        
        void createNet(int uNumberOfParticles);
    };

}

#endif /* U4DNettingSystem_hpp */
