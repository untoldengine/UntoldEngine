//
//  U4DScriptBindManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptBindManager_hpp
#define U4DScriptBindManager_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include "gravity_delegate.h"
#include <iostream>
#include <string.h>

namespace U4DEngine {

    class U4DScriptBindManager {
        
    private:
        
        
        static U4DScriptBindManager *instance;
        
    protected:
        
        U4DScriptBindManager();
        
        ~U4DScriptBindManager();
        
    public:
        
        //gravity_closure_t *closure;
        gravity_compiler_t *compiler;
        gravity_vm *vm;
        gravity_delegate_t delegate;
        
        
        static U4DScriptBindManager *sharedInstance();
        
        static void freeObjects(gravity_vm *vm, gravity_object_t *obj);
        static void registerClasses (gravity_vm *vm);
        static void reportError(gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata);
        bool loadScript(std::string uScriptPath);
        bool init();
        void cleanup();
        void initGravityFunction();
        void updateGravityFunction(double dt);
        void userInputGravityFunction(std::string uString);
        static const char *loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static);

    };

}

#endif /* U4DScriptBindManager_hpp */
