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
#include "U4DScriptBindBehavior.h"
#include "U4DScriptInstanceManager.h"
#include "U4DDirector.h"
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
                    
                    
                    //this calls the Garbage Collector in gravity
                    //gravity_gc_start(vm);
                }
            }
            
        }
        
    }


    void U4DScriptBindManager::updateGravityFunction(double dt){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){
            
            gravity_value_t update_function = gravity_vm_getvalue(vm, "update", (uint32_t)strlen("update"));
            if (!VALUE_ISA_CLOSURE(update_function)) {
                printf("Unable to find update function into Gravity VM.\n");

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

    void U4DScriptBindManager::userInputGravityFunction(void *uData){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){
            
            gravity_value_t userInput_function = gravity_vm_getvalue(vm, "userInput", (uint32_t)strlen("userInput"));
            if (!VALUE_ISA_CLOSURE(userInput_function)) {
                printf("Unable to find user-input function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *userInput_closure = VALUE_AS_CLOSURE(userInput_function);

                // prepare parameters
                
//                gravity_value_t p1 = VALUE_FROM_STRING(vm, uString.c_str(), (int)uString.length());
//
                U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
                
                //create map- 12 is the number of elements in the CONTROLLERMESSAGE STRUCT
                gravity_map_t *controllerInputMessageMap=gravity_map_new(vm,12);
                
                gravity_value_t inputElementType = VALUE_FROM_CSTRING(NULL, "inputElementType");
                gravity_value_t inputElementAction = VALUE_FROM_CSTRING(NULL, "inputElementAction");
                gravity_value_t joystickDirection = VALUE_FROM_CSTRING(NULL, "joystickDirection");
                
                gravity_value_t inputPosition = VALUE_FROM_CSTRING(NULL, "inputPosition");
                gravity_value_t previousMousePosition = VALUE_FROM_CSTRING(NULL, "previousMousePosition");
                gravity_value_t mouseDeltaPosition = VALUE_FROM_CSTRING(NULL, "mouseDeltaPosition");
                
                gravity_value_t joystickChangeDirection = VALUE_FROM_CSTRING(NULL, "joystickChangeDirection");
                gravity_value_t mouseChangeDirection = VALUE_FROM_CSTRING(NULL, "mouseChangeDirection");
                gravity_value_t arrowKeyDirection = VALUE_FROM_CSTRING(NULL, "arrowKeyDirection");
                
                gravity_value_t elementUIName = VALUE_FROM_CSTRING(NULL, "elementUIName");
                gravity_value_t dataValue = VALUE_FROM_CSTRING(NULL, "dataValue");
                
                
                //set the value to each key
                gravity_map_insert(vm,controllerInputMessageMap,inputElementType,VALUE_FROM_INT(controllerInputMessage.inputElementType));
                
                gravity_map_insert(vm,controllerInputMessageMap,inputElementAction,VALUE_FROM_INT(controllerInputMessage.inputElementAction));
                
                //joystick
                //prepare joystick data into a list before inserting it into a map
                gravity_value_t joystickDirX = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.x);
                gravity_value_t joystickDirY = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.y);
                gravity_value_t joystickDirectionValue[] = {joystickDirX,joystickDirY};
                
                gravity_list_t *joystickDirectionList=gravity_list_from_array(vm, 2, joystickDirectionValue);
                
                gravity_map_insert(vm,controllerInputMessageMap,joystickDirection,VALUE_FROM_OBJECT(joystickDirectionList));
                
                //inputposition
                gravity_value_t inputPositionX = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.x);
                gravity_value_t inputPositionY = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.y);
                gravity_value_t inputPositionValue[] = {inputPositionX,inputPositionY};
                
                gravity_list_t *inputPositionList=gravity_list_from_array(vm, 2, inputPositionValue);
                
                gravity_map_insert(vm,controllerInputMessageMap,inputPosition,VALUE_FROM_OBJECT(inputPositionList));
                
                //previousMousePosition
                gravity_value_t previousMousePositionX = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.x);
                gravity_value_t previousMousePositionY = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.y);
                gravity_value_t previousMousePositionValue[] = {previousMousePositionX,previousMousePositionY};
                
                gravity_list_t *previousMousePositionList=gravity_list_from_array(vm, 2, previousMousePositionValue);
                
                gravity_map_insert(vm,controllerInputMessageMap,previousMousePosition,VALUE_FROM_OBJECT(previousMousePositionList));
                
                //mouseDeltaPosition
                gravity_value_t mouseDeltaPositionX = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.x);
                gravity_value_t mouseDeltaPositionY = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.y);
                gravity_value_t mouseDeltaPositionValue[] = {mouseDeltaPositionX,mouseDeltaPositionY};
                
                gravity_list_t *mouseDeltaPositionList=gravity_list_from_array(vm, 2, mouseDeltaPositionValue);
                
                gravity_map_insert(vm,controllerInputMessageMap,mouseDeltaPosition,VALUE_FROM_OBJECT(mouseDeltaPositionList));
                
                //joystickChangeDirection
                gravity_map_insert(vm,controllerInputMessageMap,joystickChangeDirection,VALUE_FROM_BOOL(controllerInputMessage.joystickChangeDirection));
                
                //mouseChangeDirection
                gravity_map_insert(vm,controllerInputMessageMap,mouseChangeDirection,VALUE_FROM_BOOL(controllerInputMessage.mouseChangeDirection));
                
                //arrowKeyDirection
                gravity_value_t arrowKeyDirectionX = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.x);
                gravity_value_t arrowKeyDirectionY = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.y);
                gravity_value_t arrowKeyDirectionValue[] = {arrowKeyDirectionX,arrowKeyDirectionY};
                
                gravity_list_t *arrowKeyDirectionList=gravity_list_from_array(vm, 2, arrowKeyDirectionValue);
                
                gravity_map_insert(vm,controllerInputMessageMap,arrowKeyDirection,VALUE_FROM_OBJECT(arrowKeyDirectionList));
                

                //elementUIName
                gravity_map_insert(vm,controllerInputMessageMap,elementUIName,                VALUE_FROM_STRING(vm, controllerInputMessage.elementUIName.c_str(), (int)controllerInputMessage.elementUIName.length()));
                
                //dataValue
                gravity_map_insert(vm,controllerInputMessageMap,dataValue,VALUE_FROM_FLOAT(controllerInputMessage.dataValue));
                
                
                gravity_value_t controllerInputData=VALUE_FROM_OBJECT(controllerInputMessageMap);
                gravity_value_t params[] = {controllerInputData};
                
                // execute user-input closure
                if (gravity_vm_runclosure (vm, userInput_closure, VALUE_FROM_NULL, params, 1)) {
                    
                }
                
                gravity_map_free(vm, controllerInputMessageMap);
                gravity_list_free(vm, joystickDirectionList);
                gravity_list_free(vm, inputPositionList);
                gravity_list_free(vm, previousMousePositionList);
                gravity_list_free(vm, mouseDeltaPositionList);
                gravity_list_free(vm, arrowKeyDirectionList);
                
                
            }
        }
    }

    bool U4DScriptBindManager::loadScript(std::string uScriptPath){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        logger->log("Loading script %s",uScriptPath.c_str());
        
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        
        scriptInstanceManager->removeAllScriptInstances();
        
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
        const char *newpath = file_buildpath(path, "/Users/haroldserrano/Downloads/GameplayScripts");
        if (!newpath) return NULL;
        
        const char *buffer = file_read(newpath, size);
        mem_free(newpath);
        
        return buffer;
        
    }

    void U4DScriptBindManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        U4DScriptBindVector3n *scriptBindVector3n=U4DScriptBindVector3n::sharedInstance();
        scriptBindVector3n->vector3nFree(vm, obj);

        U4DScriptBindModel *scriptBindModel=U4DScriptBindModel::sharedInstance();
        scriptBindModel->modelFree(vm, obj);
        
        U4DScriptBindBehavior *scriptBindBehavior=U4DScriptBindBehavior::sharedInstance();
        scriptBindBehavior->scriptBehaviorFree(vm, obj);
        
    }

    void U4DScriptBindManager::registerClasses(gravity_vm *vm){
            
        U4DScriptBindVector3n *scriptBindVector3n=U4DScriptBindVector3n::sharedInstance();
        scriptBindVector3n->registerVector3nClasses(vm);
        
        registerLoggerClasses(vm);
        
        registerCameraClasses(vm);
        
        U4DScriptBindBehavior *scriptBindBehavior=U4DScriptBindBehavior::sharedInstance();
        scriptBindBehavior->registerScriptBehaviorClasses(vm);
        
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
        
        U4DDirector *director=U4DDirector::sharedInstance();
        director->setScriptRunTimeError(true);
    }

    void U4DScriptBindManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
