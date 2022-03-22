//
//  U4DFormationManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFormationManager_hpp
#define U4DFormationManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DVector3n.h"

namespace U4DEngine {

    class U4DFormationManager {
        
    private:
        
        
        std::vector<U4DVector3n> formationPositions; //moving player positions
        
    public:
        
        std::vector<U4DVector3n> spots; //original spots
        
        U4DVector3n homePosition;
        
        U4DVector3n currentPosition;
        
        U4DVector3n previousPosition;
        
        U4DFormationManager();
        
        ~U4DFormationManager();
        
        void computeFormationPosition(U4DVector3n uOffsetPosition);
        
        U4DVector3n getFormationPositionAtIndex(int uIndex);
        
        void computeHomePosition();
        
    };

}

#endif /* U4DFormationManager_hpp */
