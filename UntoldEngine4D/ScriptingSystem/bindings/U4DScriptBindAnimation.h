//
//  U4DScriptBindAnimation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindAnimation_hpp
#define U4DScriptBindAnimation_hpp

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

#include "U4DAnimation.h"

namespace U4DEngine {
   
    class U4DScriptBindAnimation {
        
    private:
        
        static U4DScriptBindAnimation *instance;
        
    protected:
        
        U4DScriptBindAnimation();
        
        ~U4DScriptBindAnimation();
        
    public:
        
        static U4DScriptBindAnimation *sharedInstance();
        
        static bool animationCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationStop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        void animationFree (gravity_vm *vm, gravity_object_t *obj);
        void registerAnimationClasses (gravity_vm *vm);

    };
    
}
#endif /* U4DScriptBindAnimation_hpp */
