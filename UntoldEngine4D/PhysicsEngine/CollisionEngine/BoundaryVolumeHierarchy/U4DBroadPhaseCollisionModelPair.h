//
//  BroadPhaseCollisionModelPair.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef BroadPhaseCollisionModelPair_hpp
#define BroadPhaseCollisionModelPair_hpp

#include <stdio.h>

namespace U4DEngine {
    class U4DDynamicModel;
}

namespace U4DEngine {
   
    class U4DBroadPhaseCollisionModelPair {
        
    private:
        
    public:
        U4DBroadPhaseCollisionModelPair();
        
        ~U4DBroadPhaseCollisionModelPair();
        
        U4DDynamicModel *model1;
        U4DDynamicModel *model2;
    };
    
}



#endif /* BroadPhaseCollisionModelPair_hpp */
