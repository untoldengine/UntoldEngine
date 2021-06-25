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
#include "U4DModel.h"
#include "gravity_value.h"

namespace U4DEngine {
    
class U4DScriptBehavior {
    
private:
    
    std::string name;
    
    std::string filename;
    
    gravity_instance_t *model_instance;
    
public:
    
    U4DModel *model;
    
    U4DScriptBehavior();
    
    ~U4DScriptBehavior();
    
    void attachScriptToModel(std::string uScriptPath,U4DModel *uModel);
    
    void init();
    
    void update(double dt);
    
    void destroy();
    
    gravity_instance_t *getModelInstance();
    
};

}


#endif /* U4DScriptBehavior_hpp */
