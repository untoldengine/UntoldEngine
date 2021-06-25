//
//  U4DScriptBindAnimManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/24/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindAnimManager_hpp
#define U4DScriptBindAnimManager_hpp

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

#include "U4DAnimationManager.h"

namespace U4DEngine {
   
    class U4DScriptBindAnimManager {
        
    private:
        
        static U4DScriptBindAnimManager *instance;
        
    protected:
        
        U4DScriptBindAnimManager();
        
        ~U4DScriptBindAnimManager();
        
    public:
        
        static U4DScriptBindAnimManager *sharedInstance();
        
        static bool animationManagerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerSetAnimToPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerRemoveCurrentPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        void animationManagerFree (gravity_vm *vm, gravity_object_t *obj);
        void registerAnimationManagerClasses (gravity_vm *vm);

    };
    
}
#endif /* U4DScriptBindAnimManager_hpp */
