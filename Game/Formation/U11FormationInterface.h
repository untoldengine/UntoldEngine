//
//  U11FormationInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11FormationInterface_hpp
#define U11FormationInterface_hpp

#include <stdio.h>
#include <vector>
#include "U11PlayerSpace.h"

class U11Team;
class U11Field;

class U11FormationInterface {
    
  
public:
    
    virtual ~U11FormationInterface(){};
    
    virtual std::vector<U11PlayerSpace> partitionField(U11Field *uField, std::string uFieldSide)=0;
    
    virtual std::vector<U11PlayerSpace> partitionFieldFromLeftSide(U11Field *uField)=0;
    
    virtual std::vector<U11PlayerSpace> partitionFieldFromRightSide(U11Field *uField)=0;
    
};

#endif /* U11FormationInterface_hpp */
