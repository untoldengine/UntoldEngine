//
//  Tank.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Tank_hpp
#define Tank_hpp

#include <stdio.h>
#include <string>
#include "Artillery.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"


class TankGun;

class Tank:public Artillery{
    
private:

    TankGun *tankGun;
    
public:

    Tank();
    
    ~Tank();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    
};

#endif /* Tank_hpp */
