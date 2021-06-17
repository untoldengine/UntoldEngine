//
//  U4DScriptBindVector3n.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindVector3n_hpp
#define U4DScriptBindVector3n_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>

#include "U4DVector3n.h"

namespace U4DEngine {

class U4DScriptBindVector3n {
    
private:
    
    static U4DScriptBindVector3n *instance;
    
protected:
    
    U4DScriptBindVector3n();
    
    ~U4DScriptBindVector3n();
    
public:
    
    static U4DScriptBindVector3n *sharedInstance();
    
    static bool vector3nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool operatorVector3nAdd (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool operatorVector3nSub (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool operatorVector3nMul (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool operatorVector3nDiv (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    static bool vector3nMagnitude(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool vector3nNormalize(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    static bool vector3nDot(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool vector3nCross(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    
    static bool vector3nShow (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool xGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool xSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool yGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool ySet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool zGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool zSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    void vector3nFree (gravity_vm *vm, gravity_object_t *obj);
    void registerVector3nClasses (gravity_vm *vm);
    
};

}
#endif /* U4DScriptBindVector3n_hpp */
