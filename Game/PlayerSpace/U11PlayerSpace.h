//
//  U11PlayerSpace.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerSpace_hpp
#define U11PlayerSpace_hpp

#include <stdio.h>
#include "U4DAABB.h"

class U11PlayerSpace {

private:
    
    U4DEngine::U4DAABB formationSpace;
    U4DEngine::U4DPoint3n homePosition;
    U4DEngine::U4DPoint3n formationPosition;
    
public:
    
    U11PlayerSpace();
    
    ~U11PlayerSpace();
    
    void setFormationSpace(U4DEngine::U4DAABB &uFormationSpace);
    
    void setHomePosition(U4DEngine::U4DPoint3n &uHomePosition);
    
    void setFormationPosition(U4DEngine::U4DPoint3n &uFormationPosition);
    
    U4DEngine::U4DPoint3n getFormationPosition();
    
    U4DEngine::U4DPoint3n getHomePosition();
    
    U4DEngine::U4DAABB getFormationSpace();
    
};

#endif /* U11PlayerSpace_hpp */
