//
//  U4DScriptBindQuaternion.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindQuaternion_hpp
#define U4DScriptBindQuaternion_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>
#include "U4DQuaternion.h"

namespace U4DEngine {

class U4DScriptBindQuaternion {

private:
    
    static U4DScriptBindQuaternion *instance;
    
protected:
    
    U4DScriptBindQuaternion();
    
    ~U4DScriptBindQuaternion();
    
public:
    
    static U4DScriptBindQuaternion *sharedInstance();
    
    static bool quaternionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool quaternionShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    void quaternionFree(gravity_vm *vm, gravity_object_t *obj);
    void registerQuaternionClasses(gravity_vm *vm);
    
};

}
#endif /* U4DScriptBindQuaternion_hpp */
