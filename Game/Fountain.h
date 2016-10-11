//
//  Fountain.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Fountain_hpp
#define Fountain_hpp

#include <stdio.h>

#include "U4DGameObject.h"

class Fountain:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Fountain();
    ~Fountain();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* Fountain_hpp */
