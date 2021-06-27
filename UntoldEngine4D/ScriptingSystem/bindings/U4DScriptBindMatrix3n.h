//
//  U4DScriptBindMatrix3n.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindMatrix3n_hpp
#define U4DScriptBindMatrix3n_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>
#include "U4DMatrix3n.h"

namespace U4DEngine {

class U4DScriptBindMatrix3n {

private:
    
    static U4DScriptBindMatrix3n *instance;
    
protected:
    
    U4DScriptBindMatrix3n();
    
    ~U4DScriptBindMatrix3n();
    
public:
    
    static U4DScriptBindMatrix3n *sharedInstance();
    
    static bool matrix3nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool matrix3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    static bool matrix3nTransformVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    void matrix3nFree(gravity_vm *vm, gravity_object_t *obj);
    void registerMatrix3nClasses(gravity_vm *vm);
    
};

}
#endif /* U4DScriptBindMatrix3n_hpp */
