//
//  U11FormationEntity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11FormationEntity_hpp
#define U11FormationEntity_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DAABB.h"

class U11FormationEntity:public U4DEngine::U4DGameObject {
    
private:
    
    U4DEngine::U4DVector3n originPosition;
    
    bool assigned;
    
    U4DEngine::U4DAABB aabbBox;
    
    
public:
    
    U11FormationEntity();
    
    ~U11FormationEntity();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void translateToOriginPosition();
    
    bool isAssigned();
    
    void setAssigned(bool uValue);
    
    U4DEngine::U4DAABB &getAABBBox();
};

#endif /* U11FormationEntity_hpp */
