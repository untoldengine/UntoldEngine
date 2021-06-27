//
//  U4DScriptBindDynamicAction.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/24/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindDynamicAction.h"
#include "U4DScriptInstanceManager.h"

namespace U4DEngine {

    U4DScriptBindDynamicAction* U4DScriptBindDynamicAction::instance=0;

    U4DScriptBindDynamicAction *U4DScriptBindDynamicAction::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptBindDynamicAction();
        }

        return instance; 
    }

    U4DScriptBindDynamicAction::U4DScriptBindDynamicAction(){
        
    }

    U4DScriptBindDynamicAction::~U4DScriptBindDynamicAction(){
        
    }

    bool U4DScriptBindDynamicAction::dynamicActionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the dynamicAction create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        gravity_instance_t *modelInstance = (gravity_instance_t *)GET_VALUE(1).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(vm, c);
        
        U4DModel *model=(U4DModel *)modelInstance->xdata;
        U4DDynamicAction *dynamicAction = new U4DDynamicAction(model);
        
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        scriptInstanceManager->loadDynamicActionScriptInstance(dynamicAction, instance);
        
        // set cpp instance and xdata of the gravity instance
        gravity_instance_setxdata(instance, dynamicAction);
        
        // return instance
        RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    }

    bool U4DScriptBindDynamicAction::dynamicActionEnableKinetic(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
        
        if (dynamicAction!=nullptr) {
            dynamicAction->enableKineticsBehavior();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
    }

    bool U4DScriptBindDynamicAction::dynamicActionEnableCollision(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
        
        if (dynamicAction!=nullptr) {
            dynamicAction->enableCollisionBehavior();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptBindDynamicAction::dynamicActionAddForce(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            gravity_instance_t *v = (gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata for both vectors
            U4DVector3n *force = (U4DVector3n *)v->xdata;
        
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->addForce(*force);
                
            }
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("A force requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptBindDynamicAction::dynamicActionGetMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
        
        if (dynamicAction!=nullptr) {
            
            float mass=dynamicAction->getMass();
            
            RETURN_VALUE(VALUE_FROM_FLOAT(mass), rindex);
        }
     
        U4DLogger *logger=U4DLogger::sharedInstance();
        logger->log("The dynamic action is null");
    
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
    }

    bool U4DScriptBindDynamicAction::dynamicActionInitMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_value_t massValue=GET_VALUE(1);
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2 && VALUE_ISA_FLOAT(massValue)) {
            
            gravity_float_t mass=massValue.f;
            
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->initMass(mass);
                
            }
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("Mass value is missing. Also, the mass type should be a float.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptBindDynamicAction::dynamicActionSetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            gravity_instance_t *v = (gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata for both vectors
            U4DVector3n *velocity = (U4DVector3n *)v->xdata;
        
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->setVelocity(*velocity);
                
            }
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("A velocity requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

bool U4DScriptBindDynamicAction::dynamicActionGetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in dynamicAction_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata
    U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
    
    if (dynamicAction!=nullptr) {
        
        U4DVector3n v=dynamicAction->getVelocity();
        
        // create a new vector type
        U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);
        
        // lookup class "U4DVector3n" already registered inside the VM
        // a faster way would be to save a global variable of type gravity_class_t *
        // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

        // error not handled here but it should be checked
        gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

        // create a Player instance
        gravity_instance_t *result = gravity_instance_new(vm, c);

        //setting the vector data to result
        gravity_instance_setxdata(result, r);
        
        RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
    }
 
    U4DLogger *logger=U4DLogger::sharedInstance();
    logger->log("Error: The dynamic action is null");

    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
}

    bool U4DScriptBindDynamicAction::dynamicActionSetGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            gravity_instance_t *v = (gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata for both vectors
            U4DVector3n *gravity = (U4DVector3n *)v->xdata;
        
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->setGravity(*gravity);
                
            }
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("A gravity requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    void U4DScriptBindDynamicAction::dynamicActionFree (gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DDynamicAction *r = (U4DDynamicAction *)instance->xdata;
        
        // explicitly free memory
        delete r;
    }

    void U4DScriptBindDynamicAction::registerDynamicActionClasses (gravity_vm *vm){
        
        gravity_class_t *dynamicAction_class = gravity_class_new_pair(vm, "U4DDynamicAction", NULL, 0, 0);
        gravity_class_t *dynamicAction_class_meta = gravity_class_get_meta(dynamicAction_class);
        
        gravity_class_bind(dynamicAction_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(dynamicActionCreate));
        gravity_class_bind(dynamicAction_class, "enableKineticBehavior", NEW_CLOSURE_VALUE(dynamicActionEnableKinetic));
        gravity_class_bind(dynamicAction_class, "enableCollisionBehavior", NEW_CLOSURE_VALUE(dynamicActionEnableCollision));
        
        gravity_class_bind(dynamicAction_class, "addForce", NEW_CLOSURE_VALUE(dynamicActionAddForce));
        gravity_class_bind(dynamicAction_class, "setVelocity", NEW_CLOSURE_VALUE(dynamicActionSetVelocity));
        gravity_class_bind(dynamicAction_class, "getVelocity", NEW_CLOSURE_VALUE(dynamicActionGetVelocity));
        gravity_class_bind(dynamicAction_class, "setGravity", NEW_CLOSURE_VALUE(dynamicActionSetGravity));
        
        gravity_class_bind(dynamicAction_class, "getMass", NEW_CLOSURE_VALUE(dynamicActionGetMass));
        
        gravity_class_bind(dynamicAction_class, "initMass", NEW_CLOSURE_VALUE(dynamicActionInitMass));

        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DDynamicAction", VALUE_FROM_OBJECT(dynamicAction_class));
        
    }


}

