//
//  U4DScriptBindAnimation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindAnimation.h"
#include "U4DScriptBindManager.h"
#include "U4DModel.h"
#include "U4DLogger.h"

#include "U4DScriptInstanceManager.h"

namespace U4DEngine {

    U4DScriptBindAnimation* U4DScriptBindAnimation::instance=0;

    U4DScriptBindAnimation* U4DScriptBindAnimation::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptBindAnimation();
        }

        return instance;
    }

    U4DScriptBindAnimation::U4DScriptBindAnimation(){
         
            
        }

    U4DScriptBindAnimation::~U4DScriptBindAnimation(){
            
        }


    bool U4DScriptBindAnimation::animationCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the animation create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        gravity_instance_t *modelInstance = (gravity_instance_t *)GET_VALUE(1).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(vm, c);
        
        U4DModel *model=(U4DModel *)modelInstance->xdata;
        U4DAnimation *animation = new U4DAnimation(model);
        
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        scriptInstanceManager->loadAnimationScriptInstance(animation, instance);
        
        // set cpp instance and xdata of the gravity instance
        gravity_instance_setxdata(instance, animation);
        
        // return instance
        RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    }

    bool U4DScriptBindAnimation::animationPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimation *animation = (U4DAnimation *)instance->xdata;
        
        if (animation!=nullptr) {
            animation->play();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptBindAnimation::animationStop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimation *animation = (U4DAnimation *)instance->xdata;
        
        if (animation!=nullptr) {
            animation->stop();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    void U4DScriptBindAnimation::animationFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DAnimation *r = (U4DAnimation *)instance->xdata;
        
        // explicitly free memory
        delete r;
    }

    void U4DScriptBindAnimation::registerAnimationClasses(gravity_vm *vm){
        
        gravity_class_t *animation_class = gravity_class_new_pair(vm, "U4DAnimation", NULL, 0, 0);
        gravity_class_t *animation_class_meta = gravity_class_get_meta(animation_class);
        
        gravity_class_bind(animation_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(animationCreate));
        gravity_class_bind(animation_class, "play", NEW_CLOSURE_VALUE(animationPlay));
        gravity_class_bind(animation_class, "stop", NEW_CLOSURE_VALUE(animationStop));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DAnimation", VALUE_FROM_OBJECT(animation_class));
    }
    

}
