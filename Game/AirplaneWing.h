//
//  AirplaneWing.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AirplaneWing_hpp
#define AirplaneWing_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "AirplanePart.h"
#include "U4DVector3n.h"

class AirplaneWing:public AirplanePart {
    
    
private:
    
public:
    
    AirplaneWing();
    
    ~AirplaneWing();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    
};
#endif /* AirplaneWing_hpp */
