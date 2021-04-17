//
//  FormationManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef FormationManager_hpp
#define FormationManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DVector3n.h"

class FormationManager{
  
private:
    
    std::vector<U4DEngine::U4DVector3n> spots; //original spots
    std::vector<U4DEngine::U4DVector3n> formationPositions; //moving player positions
    
public:
    
    FormationManager();
    
    ~FormationManager();
    
    U4DEngine::U4DVector3n homePosition;
    
    U4DEngine::U4DVector3n currentPosition;
    
    U4DEngine::U4DVector3n previousPosition;
    
    void computeHomePosition();
    
    void computeFormationPosition(U4DEngine::U4DVector3n uOffsetPosition);
    
    U4DEngine::U4DVector3n getFormationPositionAtIndex(int uIndex);
};

#endif /* FormationManager_hpp */
