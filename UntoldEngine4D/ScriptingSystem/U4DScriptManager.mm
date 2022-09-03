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
#include "U4DCamera.h"
#include "U4DGameConfigs.h"
#include "U4DSceneManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"
#include "U4DSceneStateManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DSteering.h"
#include "U4DSeek.h"
#include "U4DArrive.h"
#include "U4DPursuit.h"
#include "U4DCameraInterface.h"
#include "U4DCameraFirstPerson.h"
#include "U4DCameraThirdPerson.h"
#include "U4DCameraBasicFollow.h"


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

    void U4DScriptManager::update(int uScriptID, double dt){

//        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
//        gravity_instance_t *model_instance=scriptInstanceManager->getModelScriptInstance(uScriptID);
//
//        gravity_value_t key = VALUE_FROM_STRING(vm, "update", (uint32_t)strlen("update"));
//
//        gravity_closure_t *update_closure = (gravity_closure_t *)gravity_class_lookup_closure(gravity_value_getclass(VALUE_FROM_OBJECT(model_instance)), key);
//
//
//        if (update_closure==nullptr) {
//
////            U4DLogger *logger=U4DLogger::sharedInstance();
////            logger->log("Unable to find update method into Gravity VM");
//
//        }else{
//            gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
//            gravity_value_t params[] = {p1};
//
//            // execute closure
//            if (gravity_vm_runclosure (vm, update_closure, VALUE_FROM_OBJECT(model_instance), params, 1)) {
//
//            }
//        }

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
        
        userInputList=gravity_list_new(nullptr, 14);
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

    void U4DScriptManager::userInputClosure(void *uData){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){
                    
            gravity_value_t userInput_function = gravity_vm_getvalue(vm, "userInput", (uint32_t)strlen("userInput"));
            
            if (!VALUE_ISA_CLOSURE(userInput_function)) {
                printf("Unable to find user-input function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *userInput_closure = VALUE_AS_CLOSURE(userInput_function);
                
                U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;

                gravity_value_t inputElementType=VALUE_FROM_INT(controllerInputMessage.inputElementType);
                gravity_value_t inputElementAction=VALUE_FROM_INT(controllerInputMessage.inputElementAction);
                
                 //joystick
                 //prepare joystick data into a list before inserting it into a map
                 gravity_value_t joystickDirX = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.x);
                 gravity_value_t joystickDirY = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.y);
             
                 //inputposition
                 gravity_value_t inputPositionX = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.x);
                 gravity_value_t inputPositionY = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.y);

                //previousMousePosition
                 gravity_value_t previousMousePositionX = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.x);
                 gravity_value_t previousMousePositionY = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.y);
                
                //mouseDeltaPosition
                
                 gravity_value_t mouseDeltaPositionX = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.x);
                 gravity_value_t mouseDeltaPositionY = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.y);
                

                gravity_value_t joystickChangeDirection=VALUE_FROM_BOOL(controllerInputMessage.joystickChangeDirection);

                //mouseChangeDirection
                gravity_value_t mouseChangeDirection=VALUE_FROM_BOOL(controllerInputMessage.mouseChangeDirection);
                
                //arrowKeyDirection
                 gravity_value_t arrowKeyDirectionX = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.x);
                 gravity_value_t arrowKeyDirectionY = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.y);

                
                marray_push(gravity_value_t, userInputList->array, inputElementType);
                marray_push(gravity_value_t, userInputList->array, inputElementAction);
                
                marray_push(gravity_value_t, userInputList->array, joystickDirX);
                marray_push(gravity_value_t, userInputList->array, joystickDirY);
                
                marray_push(gravity_value_t, userInputList->array, inputPositionX);
                marray_push(gravity_value_t, userInputList->array, inputPositionY);
                
                marray_push(gravity_value_t, userInputList->array, previousMousePositionX);
                marray_push(gravity_value_t, userInputList->array, previousMousePositionY);
                
                marray_push(gravity_value_t, userInputList->array, mouseDeltaPositionX);
                marray_push(gravity_value_t, userInputList->array, mouseDeltaPositionY);
                
                marray_push(gravity_value_t, userInputList->array, joystickChangeDirection);
                marray_push(gravity_value_t, userInputList->array, mouseChangeDirection);
                
                marray_push(gravity_value_t, userInputList->array, arrowKeyDirectionX);
                marray_push(gravity_value_t, userInputList->array, arrowKeyDirectionY);
                

//            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionX);
//            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionY);

//             //elementUIName
//             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[elementUIName],VALUE_FROM_STRING(vm, controllerInputMessage.elementUIName.c_str(), (int)controllerInputMessage.elementUIName.length()));
//
//             //dataValue
//             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[dataValue],VALUE_FROM_FLOAT(controllerInputMessage.dataValue));

            
             gravity_value_t controllerInputData=VALUE_FROM_OBJECT(userInputList);
             gravity_value_t params[] = {controllerInputData};

             // execute user-input closure
             if (gravity_vm_runclosure (vm, userInput_closure, VALUE_FROM_NULL, params, 1)) {
                 
                 
             }
                
                removeItemsInList(userInputList);
                
                
            }
                
            
            
        }
        
        
    }

    void U4DScriptManager::removeItemsInList(gravity_list_t *l){
        
        size_t count = marray_size(l->array);

        //pop all items in array
        for(int i=0;i<count;i++){
            marray_pop(l->array);
        }
        
    }

    void U4DScriptManager::freeUserInputObjects(){
        
//        //free up all strings that were mem allocated
//        for(auto n:userInputElementArray){
//            gravity_string_free(vm, VALUE_AS_STRING(n));
//        }
//
//        //free up all lists that were mem allocated
//
//        gravity_list_free(vm,joystickDirectionList);
//        gravity_list_free(vm,inputPositionList);
//        gravity_list_free(vm,previousMousePositionList);
//        gravity_list_free(vm,mouseDeltaPositionList);
//        gravity_list_free(vm,arrowKeyDirectionList);
//
//        //free up map that was mem allocated
//        gravity_map_free(vm, controllerInputMessageMap);
        
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
