//
//  AirplaneRotor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AirplaneRotor_hpp
#define AirplaneRotor_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "AirplanePart.h"
#include "U4DVector3n.h"

class AirplaneRotor:public AirplanePart {
    
    
private:
    
    int rotorAngle;
    
public:
    
    AirplaneRotor();
    
    ~AirplaneRotor();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    
};
#endif /* AirplaneRotor_hpp */
