//
//  U4DScriptBindLogger.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindLogger_hpp
#define U4DScriptBindLogger_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include <iostream>

#include "U4DLogger.h"

namespace U4DEngine {

class U4DScriptBindLogger {
    
private:
    
    static U4DScriptBindLogger *instance;
    
protected:
    
    U4DScriptBindLogger();
    
    ~U4DScriptBindLogger();
    
public:
    
    static U4DScriptBindLogger *sharedInstance();
    
    static bool loggerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    static bool loggerLog(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
    void loggerFree (gravity_vm *vm, gravity_object_t *obj);
    void registerLoggerClasses (gravity_vm *vm);
    
};

}
#endif /* U4DScriptBindLogger_hpp */
