//
//  U4DGoalPost.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGoalPost_hpp
#define U4DGoalPost_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DAABB.h"


namespace U4DEngine {

class U4DGoalPost:public U4DModel {

private:
    
    bool goalBoxComputed;
    
public:
    
    U4DAABB goalBoxAABB;
    
    U4DGoalPost();
    
    ~U4DGoalPost();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    bool isBallInsideGoalBox();
    
    float distanceOfBallToGoalPost();
};

}
#endif /* U4DGoalPost_hpp */
