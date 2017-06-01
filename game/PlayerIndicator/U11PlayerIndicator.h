//
//  U11PlayerIndicator.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/31/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerIndicator_hpp
#define U11PlayerIndicator_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class U11Team;

class U11PlayerIndicator:public U4DEngine::U4DGameObject {
    
private:
    
    U11Team *team;
    
public:
    
    U11PlayerIndicator(U11Team *uTeam);
    
    ~U11PlayerIndicator();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);

    
    
};

#endif /* U11PlayerIndicator_hpp */
