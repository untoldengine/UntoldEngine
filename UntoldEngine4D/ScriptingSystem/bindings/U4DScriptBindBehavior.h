//
//  U4DScriptBindBehavior.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindBehavior_hpp
#define U4DScriptBindBehavior_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>

#include "U4DScriptBehavior.h"

namespace U4DEngine {

class U4DScriptBindBehavior {
    
private:
    
    static U4DScriptBindBehavior *instance;
    
protected:
    
    U4DScriptBindBehavior();
    
    ~U4DScriptBindBehavior();
    
public:
    
    static U4DScriptBindBehavior *sharedInstance();
    
    static bool scriptBehaviorCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    void update(int uScriptID, double dt);
    
    void scriptBehaviorFree(gravity_vm *vm, gravity_object_t *obj);
    
    void registerScriptBehaviorClasses(gravity_vm *vm);
    
};

}

#endif /* U4DScriptBindBehavior_hpp */
