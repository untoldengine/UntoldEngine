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

    void U4DScriptManager::initClosure(){
    
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
                    
                    
                    
                }
            }
            
        }
        
    }

    void U4DScriptManager::updateClosure(double dt){

         U4DDirector *director=U4DDirector::sharedInstance();

         if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){

             gravity_value_t update_function = gravity_vm_getvalue(vm, "update", (uint32_t)strlen("update"));
             if (!VALUE_ISA_CLOSURE(update_function)) {
                 //printf("Unable to find update function into Gravity VM.\n");

             }else{

                 // convert function to closure
                 gravity_closure_t *update_closure = VALUE_AS_CLOSURE(update_function);

                 // prepare parameters

                 gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
                 gravity_value_t params[] = {p1};

                 // execute init closure
                 if (gravity_vm_runclosure (vm, update_closure, VALUE_FROM_NULL, params, 1)) {
                     
                 }
             }
         }
     }

    void U4DScriptManager::loadGameConfigs(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t gameConfigs_function = gravity_vm_getvalue(vm, "gameConfigs", (uint32_t)strlen("gameConfigs"));
            if (!VALUE_ISA_CLOSURE(gameConfigs_function)) {
                printf("Unable to find gameConfigs function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *gameConfigs_closure = VALUE_AS_CLOSURE(gameConfigs_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, gameConfigs_closure, VALUE_FROM_NULL, 0, 0)) {
                    
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
        //we have to initialize the script again if there was a script-runtime error. But first we need to free all user inputs objects created such as lists and maps
        //IT SEEMS THAT SINCE I'M TRANSFERRING OWNERSHIP TO GRAVITY, THAT I SHOULDN'T HAVE TO DO THIS. LEAVING IT HERE JUST IN CASE I'M WRONG.
        //freeUserInputObjects();
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
            .loadfile_callback = loadFileCallback
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
            
        //untold
//        gravity_class_t *worldClass = gravity_class_new_pair(vm, "U4DWorld", NULL, 0, 0);
//        gravity_class_t *worldClassMeta = gravity_class_get_meta(worldClass);
//
//        gravity_class_bind(worldClassMeta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(worldCreate));
//        gravity_class_bind(worldClass, "loadModel", NEW_CLOSURE_VALUE(loadModel));
//        gravity_class_bind(worldClass, "removeModel", NEW_CLOSURE_VALUE(removeModel));
//        gravity_class_bind(worldClass, "anchorMouse", NEW_CLOSURE_VALUE(anchorMouse));
//        gravity_class_bind(worldClass, "pauseScene", NEW_CLOSURE_VALUE(pauseScene));
//        gravity_class_bind(worldClass, "playScene", NEW_CLOSURE_VALUE(playScene));
//
//        // register logger class inside VM
//        gravity_vm_setvalue(vm, "U4DWorld", VALUE_FROM_OBJECT(worldClass));
        
        
        
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

    const char *U4DScriptManager::loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static) {
         (void) fileid, (void) xdata;
         if (is_static) *is_static = false;

         if (file_exists(path)) return file_read(path, size);

         // this unittest is able to resolve path only next to main test folder (not in nested folders)
         const char *newpath = file_buildpath(path, "/Users/haroldserrano/Desktop/UntoldEngineStudio/ScriptingSystem/ScriptingSystem");
         if (!newpath) return NULL;

         const char *buffer = file_read(newpath, size);
         mem_free(newpath);

         return buffer;

     }

    void U4DScriptManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
