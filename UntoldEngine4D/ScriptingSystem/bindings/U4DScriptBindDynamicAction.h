//
//  U4DScriptBindDynamicAction.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/24/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindDynamic_hpp
#define U4DScriptBindDynamic_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include "gravity_hash.h"
#include <iostream>

#include "U4DDynamicAction.h"

namespace U4DEngine {

    class U4DScriptBindDynamicAction {
        
    private:
        
        static U4DScriptBindDynamicAction *instance;
        
    protected:
        
        U4DScriptBindDynamicAction();
        
        ~U4DScriptBindDynamicAction();
        
    public:
        
        static U4DScriptBindDynamicAction *sharedInstance();
        
        static bool dynamicActionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionEnableKinetic(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionEnableCollision(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionAddForce(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionGetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionGetMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionInitMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetFilterCategory(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetFilterMask(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        void dynamicActionFree (gravity_vm *vm, gravity_object_t *obj);
        void registerDynamicActionClasses (gravity_vm *vm);
    };

}


#endif /* U4DScriptBindDynamic_hpp */
