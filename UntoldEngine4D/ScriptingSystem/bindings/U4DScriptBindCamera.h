//
//  U4DScriptBindCamera.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindCamera_hpp
#define U4DScriptBindCamera_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>

#include "U4DCamera.h"

namespace U4DEngine {

class U4DScriptBindCamera {
    
private:
    
    static U4DScriptBindCamera *instance;
    
protected:
    
    U4DScriptBindCamera();
    
    ~U4DScriptBindCamera();
    
public:
    
    static U4DScriptBindCamera *sharedInstance();
    
    static bool cameraCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool cameraTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool cameraTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool cameraRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool cameraRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    void cameraFree (gravity_vm *vm, gravity_object_t *obj);
    void registerCameraClasses (gravity_vm *vm);
    
};

}
#endif /* U4DScriptBindCamera_hpp */
