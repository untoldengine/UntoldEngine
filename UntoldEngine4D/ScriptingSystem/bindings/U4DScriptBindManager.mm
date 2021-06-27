//
//  U4DScriptBindManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindManager.h"
#include "U4DScriptBindVector3n.h"
#include "U4DScriptBindMatrix3n.h"
#include "U4DScriptBindMatrix4n.h"
#include "U4DScriptBindQuaternion.h"
#include "U4DScriptBindLogger.h"
#include "U4DScriptBindCamera.h"
#include "U4DScriptBindModel.h"
#include "U4DScriptBindAnimation.h"
#include "U4DScriptBindAnimManager.h"
#include "U4DScriptBindDynamicAction.h"


#include "U4DLogger.h"


namespace U4DEngine {

    U4DScriptBindManager* U4DScriptBindManager::instance=0;

    U4DScriptBindManager* U4DScriptBindManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptBindManager();
        }

        return instance;
    }

    U4DScriptBindManager::U4DScriptBindManager(){
     
        //initialize script manager
        init();
    }

    U4DScriptBindManager::~U4DScriptBindManager(){
        
    }

    void U4DScriptBindManager::initGravityFunction(){
        
        gravity_value_t init_function = gravity_vm_getvalue(vm, "init", (uint32_t)strlen("init"));
        if (!VALUE_ISA_CLOSURE(init_function)) {
            printf("Unable to find init function into Gravity VM.\n");
            
        }else{
            
            // convert function to closure
            gravity_closure_t *init_closure = VALUE_AS_CLOSURE(init_function);

            // execute init closure
            if (gravity_vm_runclosure (vm, init_closure, VALUE_FROM_NULL, 0, 0)) {
                
            }
        }
        
    }


    void U4DScriptBindManager::updateGravityFunction(double dt){
        
        
//        gravity_value_t update_function = gravity_vm_getvalue(vm, "update", (uint32_t)strlen("update"));
//        if (!VALUE_ISA_CLOSURE(update_function)) {
//            printf("Unable to find update function into Gravity VM.\n");
//
//        }else{
//
//            // convert function to closure
//            gravity_closure_t *update_closure = VALUE_AS_CLOSURE(update_function);
//
//            // prepare parameters
//
//            gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
//            gravity_value_t params[] = {p1};
//
//            // execute init closure
//            if (gravity_vm_runclosure (vm, update_closure, VALUE_FROM_NULL, params, 1)) {
//
//            }
//        }
        
    }

    void U4DScriptBindManager::userInputGravityFunction(std::string uString){
        gravity_value_t userInput_function = gravity_vm_getvalue(vm, "userInput", (uint32_t)strlen("userInput"));
        if (!VALUE_ISA_CLOSURE(userInput_function)) {
            printf("Unable to find user-input function into Gravity VM.\n");
            
        }else{
            
            // convert function to closure
            gravity_closure_t *userInput_closure = VALUE_AS_CLOSURE(userInput_function);

            // prepare parameters
            
            gravity_value_t p1 = VALUE_FROM_STRING(vm, uString.c_str(), (int)uString.length());
            gravity_value_t params[] = {p1};
            
            // execute user-input closure
            if (gravity_vm_runclosure (vm, userInput_closure, VALUE_FROM_NULL, params, 1)) {
                
            }
        }
    }

    bool U4DScriptBindManager::loadScript(std::string uScriptPath){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        logger->log("Loading script %s",uScriptPath.c_str());
        
        // setup compiler
        compiler = gravity_compiler_create(&delegate);
        
        size_t size = 0;
        const char *source_code = file_read(uScriptPath.c_str(), &size);
        gravity_closure_t *closure = gravity_compiler_run(compiler, source_code, size, 0, false, true);
        
        if (!closure){
            
            // an error occurred while compiling source code and it has already been reported by the report_error callback
            gravity_compiler_free(compiler);
            return false; // syntax/semantic error
        }
        
        gravity_vm_loadclosure(vm, closure);
        
        // transfer memory from compiler to VM
        gravity_compiler_transfer(compiler, vm);
        
        gravity_compiler_free(compiler);
        
        return true;
        
    }

    bool U4DScriptBindManager::init(){
        
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

const char *U4DScriptBindManager::loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static) {
        (void) fileid, (void) xdata;
        if (is_static) *is_static = false;
        
        if (file_exists(path)) return file_read(path, size);
        
        // this unittest is able to resolve path only next to main test folder (not in nested folders)
        const char *newpath = file_buildpath(path, "/Users/haroldserrano/Downloads/");
        if (!newpath) return NULL;
        
        const char *buffer = file_read(newpath, size);
        mem_free(newpath);
        
        return buffer;
        
    }

    void U4DScriptBindManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        //vector3nFree(vm, obj);

    }

    void U4DScriptBindManager::registerClasses(gravity_vm *vm){
            
        U4DScriptBindVector3n *scriptBindVector3n=U4DScriptBindVector3n::sharedInstance();
        scriptBindVector3n->registerVector3nClasses(vm);
        
        registerLoggerClasses(vm);
        
        registerCameraClasses(vm);
        
        U4DScriptBindModel *scriptBindModel=U4DScriptBindModel::sharedInstance();
        scriptBindModel->registerModelClasses(vm);
        
        U4DScriptBindAnimation *scriptBindAnimation=U4DScriptBindAnimation::sharedInstance();
        scriptBindAnimation->registerAnimationClasses(vm);
        
        U4DScriptBindAnimManager *scriptBindAnimManager=U4DScriptBindAnimManager::sharedInstance();
        scriptBindAnimManager->registerAnimationManagerClasses(vm);
        
        U4DScriptBindDynamicAction *scriptBindDynamicAction=U4DScriptBindDynamicAction::sharedInstance();
        
        scriptBindDynamicAction->registerDynamicActionClasses(vm);
        
        U4DScriptBindMatrix4n *scriptBindMatrix4n=U4DScriptBindMatrix4n::sharedInstance();
        scriptBindMatrix4n->registerMatrix4nClasses(vm);
        
        U4DScriptBindMatrix3n *scriptBindMatrix3n=U4DScriptBindMatrix3n::sharedInstance();
        scriptBindMatrix3n->registerMatrix3nClasses(vm);
        
        U4DScriptBindQuaternion *scriptBindQuaternion=U4DScriptBindQuaternion::sharedInstance();
        
        scriptBindQuaternion->registerQuaternionClasses(vm);
        
    }

    void U4DScriptBindManager::reportError (gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata) {
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
        }

    void U4DScriptBindManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
