//
//  Bench.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Bench_hpp
#define Bench_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Bench:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Bench();
    ~Bench();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Bench_hpp */
