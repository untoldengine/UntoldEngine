//
//  U4DScriptBehavior.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBehavior_hpp
#define U4DScriptBehavior_hpp

#include <stdio.h>
#include <string>
#include "U4DEntity.h"

namespace U4DEngine {
    
class U4DScriptBehavior:public U4DEntity {
    
private:

    
public:
    
    
    U4DScriptBehavior();
    
    ~U4DScriptBehavior();
    
    void init();
    
    void update(double dt);
    
    void destroy();
    
};

}


#endif /* U4DScriptBehavior_hpp */
