//
//  U4DScriptBindBehavior.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindBehavior.h"
#include "U4DLogger.h"
#include "U4DScriptBindManager.h"
#include "U4DScriptInstanceManager.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"

namespace U4DEngine {

U4DScriptBindBehavior* U4DScriptBindBehavior::instance=0;

U4DScriptBindBehavior* U4DScriptBindBehavior::sharedInstance(){

    if (instance==0) {
        instance=new U4DScriptBindBehavior();
    }

    return instance;
}

U4DScriptBindBehavior::U4DScriptBindBehavior(){

}

U4DScriptBindBehavior::~U4DScriptBindBehavior(){

}
// MARK: - Gravity Bridge -

bool U4DScriptBindBehavior::scriptBehaviorCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // self parameter is the u4dvector3n_class create in register_cpp_classes
    gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
    
    // create Gravity instance and set its class to c
    gravity_instance_t *instance = gravity_instance_new(vm, c);
    
    U4DScriptBehavior *scriptBehavior = new U4DScriptBehavior();
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    
    U4DScene *scene=sceneManager->getCurrentScene();
    
    U4DWorld *world=scene->getGameWorld();
    
    if (scene!=nullptr && world!=nullptr) {
        world->addChild(scriptBehavior);
        
    }
    U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
    
    scriptInstanceManager->loadScriptBehaviorInstance(scriptBehavior, instance);

    // set cpp instance and xdata of the gravity instance
    gravity_instance_setxdata(instance, scriptBehavior);
    
    // return instance
    RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);

}

void U4DScriptBindBehavior::scriptBehaviorFree(gravity_vm *vm, gravity_object_t *obj){
    
    gravity_instance_t *instance = (gravity_instance_t *)obj;
    
    // get xdata (which is a U4DScriptBehavior instance)
    U4DScriptBehavior *r = (U4DScriptBehavior *)instance->xdata;
    
    // explicitly free memory
    delete r;
    
}

void U4DScriptBindBehavior::update(int uScriptID, double dt){

    U4DScriptBindManager *bindManager=U4DScriptBindManager::sharedInstance();
    
    U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
    
    gravity_instance_t *scriptBehaviorInstance=scriptInstanceManager->getScriptBehaviorInstance(uScriptID); 
    
    gravity_value_t key = VALUE_FROM_STRING(bindManager->vm, "update", (uint32_t)strlen("update"));

    gravity_closure_t *update_closure = (gravity_closure_t *)gravity_class_lookup_closure(gravity_value_getclass(VALUE_FROM_OBJECT(scriptBehaviorInstance)), key);


    if (update_closure==nullptr) {

//            U4DLogger *logger=U4DLogger::sharedInstance();
//            logger->log("Unable to find update method into Gravity VM");

    }else{
        gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
        gravity_value_t params[] = {p1};

        // execute closure
        if (gravity_vm_runclosure (bindManager->vm, update_closure, VALUE_FROM_OBJECT(scriptBehaviorInstance), params, 1)) {

        }
    }

}

void U4DScriptBindBehavior::registerScriptBehaviorClasses(gravity_vm *vm){
    
    //create vector3n class
    
    gravity_class_t *scriptBehavior_class = gravity_class_new_pair(vm, "U4DScriptBehavior", NULL, 0, 0);
    gravity_class_t *scriptBehavior_class_meta = gravity_class_get_meta(scriptBehavior_class);
    
    gravity_class_bind(scriptBehavior_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(scriptBehaviorCreate));
    
    
    
    // register vector3n class inside VM
    gravity_vm_setvalue(vm, "U4DScriptBehavior", VALUE_FROM_OBJECT(scriptBehavior_class));
    
}

}
