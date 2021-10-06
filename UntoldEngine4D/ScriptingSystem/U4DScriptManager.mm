//
//  U4DScriptManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptManager.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DGameConfigs.h"

namespace U4DEngine {

    U4DScriptManager* U4DScriptManager::instance=0;

    U4DScriptManager* U4DScriptManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptManager();
        }

        return instance;
    }

    U4DScriptManager::U4DScriptManager(){
     
        //initialize script manager
        init();
    }

    U4DScriptManager::~U4DScriptManager(){
        
    }

    void U4DScriptManager::loadGameConfigs(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t init_function = gravity_vm_getvalue(vm, "init", (uint32_t)strlen("init"));
            if (!VALUE_ISA_CLOSURE(init_function)) {
                printf("Unable to find init function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *init_closure = VALUE_AS_CLOSURE(init_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, init_closure, VALUE_FROM_NULL, 0, 0)) {
                    
                    // retrieve returned result
                    gravity_value_t result = gravity_vm_result(vm);
                    
                    if(VALUE_ISA_MAP(result)){
                                            
                        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
                        
                        gravity_map_t *map = VALUE_AS_MAP(result);
                        
                        std::map<std::string,float>::iterator it=gameConfigs->configsMap.begin();
                        
                        //iterate over the map
                        while (it!=gameConfigs->configsMap.end()) {
                            
                            //Access key from first element
                            std::string paramKeyName=it->first;
                            
                            gravity_value_t gravityParamKey = VALUE_FROM_CSTRING(NULL, paramKeyName.c_str());
                            
                            gravity_value_t *gravityValue = gravity_hash_lookup(map->hash, gravityParamKey); 
                            
                            gravity_float_t v=gravityValue->f;
                            
                            it->second=v;
                            
                            it++;
                        }
     
                    }
                    
                }
            }
            
        }
        
    }

    bool U4DScriptManager::loadScript(std::string uScriptPath){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        logger->log("Loading script %s",uScriptPath.c_str());
    
        if(director->getScriptRunTimeError()==true){
            //we have to initialize the script again if there was a script-runtime error
            init();
        }
        
        // setup compiler
        compiler = gravity_compiler_create(&delegate);
        
        size_t size = 0;
        const char *source_code = file_read(uScriptPath.c_str(), &size);
        gravity_closure_t *closure = gravity_compiler_run(compiler, source_code, size, 0, false, true);
        
        if (!closure){
            
            // an error occurred while compiling source code and it has already been reported by the report_error callback
            
            
            director->setScriptCompiledSuccessfully(false);
            
            gravity_compiler_free(compiler);
            return false; // syntax/semantic error
        }
        
        director->setScriptCompiledSuccessfully(true);
        director->setScriptRunTimeError(false);
        
        gravity_vm_loadclosure(vm, closure);
        
        // transfer memory from compiler to VM
        gravity_compiler_transfer(compiler, vm);
        
        gravity_compiler_free(compiler);
        
        return true;
        
    }

    bool U4DScriptManager::init(){
        
        // setup delegate
        delegate = {
            .error_callback = reportError,
            .bridge_free = freeObjects,
        };
        
        
        // setup Gravity VM
        vm = gravity_vm_new(&delegate);
        
        // register my C++ classes inside Gravity VM
        registerClasses(vm);
        
        //if (loadScript(uScriptPath)) {
            
         
            return true;
        //}
        
        //return false;
        
    }

    void U4DScriptManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        
        
    }

    void U4DScriptManager::registerClasses(gravity_vm *vm){
            
        
        
    }

    void U4DScriptManager::reportError (gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata) {
            #pragma unused(vm, xdata)
            
        U4DLogger *logger=U4DLogger::sharedInstance();
        
            const char *type = "N/A";
            switch (error_type) {
                case GRAVITY_ERROR_NONE: type = "NONE"; break;
                case GRAVITY_ERROR_SYNTAX: type = "SYNTAX"; break;
                case GRAVITY_ERROR_SEMANTIC: type = "SEMANTIC"; break;
                case GRAVITY_ERROR_RUNTIME: type = "RUNTIME"; break;
                case GRAVITY_WARNING: type = "WARNING"; break;
                case GRAVITY_ERROR_IO: type = "I/O"; break;
            }
            
            if (error_type == GRAVITY_ERROR_RUNTIME) logger->log("RUNTIME ERROR: ");
            else logger->log("%s ERROR on %d (%d,%d): ", type, error_desc.fileid, error_desc.lineno, error_desc.colno);
            logger->log("%s\n", message);
        
        U4DDirector *director=U4DDirector::sharedInstance();
        director->setScriptRunTimeError(true);
    }

    void U4DScriptManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
