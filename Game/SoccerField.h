//
//  SoccerField.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerField_hpp
#define SoccerField_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class SoccerField:public U4DEngine::U4DGameObject {
    
private:
    
public:
    SoccerField();
    
    ~SoccerField();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
};
#endif /* SoccerField_hpp */
