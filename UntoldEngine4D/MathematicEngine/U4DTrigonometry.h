//
//  U4DTrigonometry.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/14/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DTrigonometry_hpp
#define U4DTrigonometry_hpp

#include <stdio.h>

namespace U4DEngine {
    
    class U4DTrigonometry{
        
    private:
        
    public:
        U4DTrigonometry();
        ~U4DTrigonometry();
        
        float degreesToRad(float uAngle);
        
        float radToDegrees(float uAngle);
    };
}

#endif /* U4DTrigonometry_hpp */
