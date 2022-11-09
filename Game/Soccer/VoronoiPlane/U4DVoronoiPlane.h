//
//  U4DVoronoiPlane.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/29/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DVoronoiPlane_hpp
#define U4DVoronoiPlane_hpp

#include <stdio.h>
#include <vector>
#include "U4DModel.h"
#include "U4DSegment.h"

namespace U4DEngine {

class U4DVoronoiPlane:public U4DModel {

private:
    
    
public:
    
    U4DVoronoiPlane();
    
    ~U4DVoronoiPlane();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void shade(std::vector<U4DSegment> uSegments);
    
};

}

#endif /* U4DVoronoiPlane_hpp */
