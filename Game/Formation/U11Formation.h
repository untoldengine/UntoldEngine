//
//  U11Formation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Formation_hpp
#define U11Formation_hpp

#include <stdio.h>
#include "U11FormationInterface.h"
#include <vector>
#include "U11PlayerSpace.h"
#include "UserCommonProtocols.h"

class U11Formation:public U11FormationInterface {
    
private:
    
public:
    
    U11Formation();
    
    ~U11Formation();
    
    std::vector<U11PlayerSpace> partitionField(U11Field *uField, std::string uFieldSide){};
    
    std::vector<U11PlayerSpace> partitionFieldFromLeftSide(U11Field *uField){};
    
    std::vector<U11PlayerSpace> partitionFieldFromRightSide(U11Field *uField){};
    
    std::vector<U4DEngine::U4DAABB> partitionAABBAlongDirection(U4DEngine::U4DAABB &uAABB,U4DEngine::U4DVector3n &uDirection, int uSpaces);
    
    
};

#endif /* U11Formation_hpp */
