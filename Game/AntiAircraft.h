//
//  AntiAircraft.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AntiAircraft_hpp
#define AntiAircraft_hpp

#include <stdio.h>
#include <string>
#include "Artillery.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DWorld.h"

class AntiAircraftGun;
class AntiAircraftRotor;


class AntiAircraft:public Artillery{
    
private:
    
    AntiAircraftGun *antiAircraftGun;
    AntiAircraftRotor *antiAircraftRotor;
    
public:
    
    AntiAircraft();
    
    ~AntiAircraft();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DVector3n getAimVector();
    
    AntiAircraftGun* getAntiAircraftGun();
    
    AntiAircraftRotor* getAntiAircraftRotor();
    
};
#endif /* AntiAircraft_hpp */
