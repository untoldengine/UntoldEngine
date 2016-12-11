//
//  Airplane.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Airplane_hpp
#define Airplane_hpp

#include <stdio.h>
#include "Artillery.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class AirplaneRotor;
class AirplaneWing;

class Airplane:public Artillery {
    
private:
    
    AirplaneRotor *rotor;
    AirplaneWing *leftWing;
    AirplaneWing *rightWing;
    U4DEngine::U4DCallback<Airplane>* scheduler;
    U4DEngine::U4DTimer *shootingTimer;
    
public:
    
    Airplane();
    
    ~Airplane();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Airplane_hpp */
