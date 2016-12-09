//
//  Flank.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Flank_hpp
#define Flank_hpp

#include <stdio.h>
#include <string>
#include "Artillery.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"


class FlankGun;
class FlankRotor;

class Flank:public Artillery{
    
private:
    
    FlankGun *flankGun;
    FlankRotor *flankRotor;
    
public:
    
    Flank();
    
    ~Flank();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DVector3n getAimVector();
};
#endif /* Flank_hpp */
