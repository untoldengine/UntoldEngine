//
//  U4DScriptBindQuaternion.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindQuaternion.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DScriptBindQuaternion *U4DScriptBindQuaternion::instance=0;

U4DScriptBindQuaternion::U4DScriptBindQuaternion(){
    
}

U4DScriptBindQuaternion::~U4DScriptBindQuaternion(){
    
}

U4DScriptBindQuaternion *U4DScriptBindQuaternion::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindQuaternion();
    }
    
    return instance;
}

bool U4DScriptBindQuaternion::quaternionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    //self parameter is U4DQuaternion class
    gravity_class_t *c=(gravity_class_t*)GET_VALUE(0).p;
    gravity_value_t scalarValue=GET_VALUE(1);
    gravity_value_t vectorValue=GET_VALUE(2);
    
    if(nargs==3){
        
        if (VALUE_ISA_FLOAT(scalarValue) && VALUE_ISA_INSTANCE(vectorValue)) {
            
            gravity_float_t s=scalarValue.f;
            
            gravity_instance_t *vectorInstance = (gravity_instance_t *)vectorValue.p;
            
            //create a gravity instance
            gravity_instance_t *instance=gravity_instance_new(vm, c);
            
            U4DVector3n *v=(U4DVector3n*)vectorInstance->xdata;
            
            //allocate the U4DQuaternion class-identity matrix
            U4DQuaternion *r=new U4DQuaternion(s,*v); 
            
            //set the cpp instance and xdata
            gravity_instance_setxdata(instance, r);
            
            RETURN_VALUE(VALUE_FROM_OBJECT(instance),rindex);
        }
        
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Unable to create a U4DQuaternion object.");
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

bool U4DScriptBindQuaternion::quaternionShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in matrix4n_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata
    U4DQuaternion *r = (U4DQuaternion *)instance->xdata;
    
    r->show();
    
    RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
    
}

void U4DScriptBindQuaternion::quaternionFree(gravity_vm *vm, gravity_object_t *obj){
    
    gravity_instance_t *instance = (gravity_instance_t *)obj;
    
    // get xdata (which is a U4DQuaternion instance)
    U4DQuaternion *r = (U4DQuaternion *)instance->xdata;
    
    // explicitly free memory
    delete r;
    
}

void U4DScriptBindQuaternion::registerQuaternionClasses(gravity_vm *vm){
    
    
    gravity_class_t *quaternion_class = gravity_class_new_pair(vm, "U4DQuaternion", NULL, 0, 0);
    gravity_class_t *quaternion_class_meta = gravity_class_get_meta(quaternion_class);
    
    gravity_class_bind(quaternion_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(quaternionCreate));
    gravity_class_bind(quaternion_class, "show", NEW_CLOSURE_VALUE(quaternionShow));
    
    // register U4DQuaternion class inside VM
    gravity_vm_setvalue(vm, "U4DQuaternion", VALUE_FROM_OBJECT(quaternion_class));
    
    
}

}
