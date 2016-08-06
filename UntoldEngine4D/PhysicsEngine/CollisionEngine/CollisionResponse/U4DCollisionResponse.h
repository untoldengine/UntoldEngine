//
//  U4DCollisionResponse.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DCollisionResponse_hpp
#define U4DCollisionResponse_hpp

#include <stdio.h>
#include <vector>
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DDynamicModel;
    class U4DVector3n;
    
}

namespace U4DEngine {
    
    class U4DCollisionResponse{
        
    private:
        
    public:
        
        U4DCollisionResponse();
        ~U4DCollisionResponse();
        
        void collisionResolution(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,COLLISIONMANIFOLDONODE &uCollisionManifoldNode);
        
    };
}

#endif /* U4DCollisionResponse_hpp */
