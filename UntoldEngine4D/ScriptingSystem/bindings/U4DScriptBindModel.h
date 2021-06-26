//
//  U4DScriptBindModel.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindModel_hpp
#define U4DScriptBindModel_hpp

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

#include "U4DModel.h"

namespace U4DEngine {
   
    class U4DScriptBindModel {
        
    private:
        
        static U4DScriptBindModel *instance;
        
    protected:
        
        U4DScriptBindModel();
        
        ~U4DScriptBindModel();
        
    public:
        
        static U4DScriptBindModel *sharedInstance();
        
        static bool modelCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelLoad(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelAddChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelGetAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelSetLocalSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelSetPipeline(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelLoadAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelGetBoneRestPose(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelGetBoneAnimationPose(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        
        void modelFree (gravity_vm *vm, gravity_object_t *obj);
        void registerModelClasses (gravity_vm *vm);

    //    void initGravityFunction();
        void update(int uScriptID, double dt);
        
        
        
    };
    
}

#endif /* U4DScriptBindModel_hpp */
