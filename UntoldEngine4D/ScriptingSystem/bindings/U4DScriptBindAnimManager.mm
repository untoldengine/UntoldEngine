//
//  U4DScriptBindAnimManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/24/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindAnimManager.h"
#include "U4DScriptBindManager.h"
#include "U4DLogger.h"
#include "U4DAnimation.h"
#include "U4DScriptInstanceManager.h"

namespace U4DEngine {

    U4DScriptBindAnimManager* U4DScriptBindAnimManager::instance=0;

    U4DScriptBindAnimManager* U4DScriptBindAnimManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptBindAnimManager();
        }

        return instance;
    }

    U4DScriptBindAnimManager::U4DScriptBindAnimManager(){
         
            
        }

    U4DScriptBindAnimManager::~U4DScriptBindAnimManager(){
            
        }


    bool U4DScriptBindAnimManager::animationManagerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the animation manager create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(vm, c);
        
        U4DAnimationManager *animationManager = new U4DAnimationManager();
        
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        
        scriptInstanceManager->loadAnimManagerScriptInstance(animationManager, instance);
        
        // set cpp instance and xdata of the gravity instance
        gravity_instance_setxdata(instance, animationManager);
        
        // return instance
        RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    }

    bool U4DScriptBindAnimManager::animationManagerSetAnimToPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_instance_t *animationInstance = (gravity_instance_t *)GET_VALUE(1).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
        U4DAnimation *animation=(U4DAnimation*)animationInstance->xdata;
        
        if (animationManager!=nullptr && animation!=nullptr) {
            animationManager->setAnimationToPlay(animation);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptBindAnimManager::animationManagerPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
        
        if (animationManager!=nullptr) {
            animationManager->playAnimation();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptBindAnimManager::animationManagerRemoveCurrentPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
        
        if (animationManager!=nullptr) {
            animationManager->removeCurrentPlayingAnimation();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    void U4DScriptBindAnimManager::animationManagerFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DAnimationManager *r = (U4DAnimationManager *)instance->xdata;
        
        // explicitly free memory
        delete r;
    }

    void U4DScriptBindAnimManager::registerAnimationManagerClasses(gravity_vm *vm){
        
        gravity_class_t *animationManager_class = gravity_class_new_pair(vm, "U4DAnimationManager", NULL, 0, 0);
        
        gravity_class_t *animationManager_class_meta = gravity_class_get_meta(animationManager_class);
        
        gravity_class_bind(animationManager_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(animationManagerCreate));
        
        gravity_class_bind(animationManager_class, "setAnimationToPlay", NEW_CLOSURE_VALUE(animationManagerSetAnimToPlay));
        
        gravity_class_bind(animationManager_class, "playAnimation", NEW_CLOSURE_VALUE(animationManagerPlayAnim));
        
        gravity_class_bind(animationManager_class, "removeCurrentPlayingAnimation", NEW_CLOSURE_VALUE(animationManagerRemoveCurrentPlayAnim));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DAnimationManager", VALUE_FROM_OBJECT(animationManager_class));
    }
    

}
