//
//  U11212Formation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11212Formation_hpp
#define U11212Formation_hpp

#include <stdio.h>
#include "U11Formation.h"

class U11212Formation:public U11Formation {
    
public:
    
    U11212Formation();
    
    ~U11212Formation();
    
    std::vector<U11PlayerSpace> partitionField(U11Field *uField, std::string uFieldSide);
    
    std::vector<U11PlayerSpace> partitionFieldFromLeftSide(U11Field *uField);
    
    std::vector<U11PlayerSpace> partitionFieldFromRightSide(U11Field *uField);
    
};

#endif /* U11212Formation_hpp */
