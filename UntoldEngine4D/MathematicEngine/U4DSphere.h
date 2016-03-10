//
//  U4DSphere.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DSphere_hpp
#define U4DSphere_hpp

#include <stdio.h>
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    class U4DSphere {
        
    private:
        U4DPoint3n center;
        float radius;
        
    public:
        
        U4DSphere();
        
        U4DSphere(U4DPoint3n &uCenter, float uRadius);
        
        ~U4DSphere();
        
        void setCenter(U4DPoint3n &uCenter);
        void setRadius(float uRadius);
        
        U4DPoint3n getCenter();
        float getRadius();
        
        bool intersectionWithVolume(U4DSphere &uSphere);
        
    };

}

#endif /* U4DSphere_hpp */
