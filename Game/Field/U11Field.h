//
//  U11Field.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Field_hpp
#define U11Field_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U11Ball.h"

class U11Field:public U4DEngine::U4DGameObject {
    
private:
    
    U11Ball *soccerBallEntity;
    
public:
    U11Field();
    
    ~U11Field();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void setBallEntity(U11Ball *uU11Ball);
    
    void update(double dt);
    
    
};
#endif /* U11Field_hpp */
