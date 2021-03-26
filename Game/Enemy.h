//
//  Enemy.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Enemy_hpp
#define Enemy_hpp

#include <stdio.h>
#include "Player.h"


class Enemy: public Player {
    
private:
    
    
    
public:
    
    Enemy();
    
    ~Enemy();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
};

#endif /* Enemy_hpp */
