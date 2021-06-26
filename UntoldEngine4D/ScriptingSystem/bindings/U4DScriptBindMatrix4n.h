//
//  U4DScriptBindMatrix4n.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/25/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindMatrix4n_hpp
#define U4DScriptBindMatrix4n_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>
#include "U4DMatrix4n.h"

namespace U4DEngine {

class U4DScriptBindMatrix4n {

private:
    
    static U4DScriptBindMatrix4n *instance;
    
protected:
    
    U4DScriptBindMatrix4n();
    
    ~U4DScriptBindMatrix4n();
    
public:
    
    static U4DScriptBindMatrix4n *sharedInstance();
    
    static bool matrix4nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool matrix4nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    void matrix4nFree(gravity_vm *vm, gravity_object_t *obj);
    void registerMatrix4nClasses(gravity_vm *vm);
    
};

}

#endif /* U4DScriptBindMatrix4n_hpp */
