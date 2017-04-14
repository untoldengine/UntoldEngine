//
//  U11FieldGoal.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11FieldGoal_hpp
#define U11FieldGoal_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DSegment.h"

class U11FieldGoal:public U4DEngine::U4DGameObject {

private:
    
    U4DEngine::U4DSegment fieldGoalWidthSegment;
    
public:
    
    U11FieldGoal();
    
    ~U11FieldGoal();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void computeFieldGoalWidthSegment();
    
    U4DEngine::U4DSegment getFieldGoalWidthSegment();
    
};

#endif /* U11FieldGoal_hpp */
