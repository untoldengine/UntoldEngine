//
//  U4DScriptBindMatrix3n.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindMatrix3n.h"
#include "U4DLogger.h"
#include "U4DVector3n.h"

namespace U4DEngine {

U4DScriptBindMatrix3n *U4DScriptBindMatrix3n::instance=0;

U4DScriptBindMatrix3n::U4DScriptBindMatrix3n(){
    
}

U4DScriptBindMatrix3n::~U4DScriptBindMatrix3n(){
    
}

U4DScriptBindMatrix3n *U4DScriptBindMatrix3n::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindMatrix3n();
    }
    
    return instance;
}

bool U4DScriptBindMatrix3n::matrix3nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    //self parameter is U4DMatrix3n class
    gravity_class_t *c=(gravity_class_t*)GET_VALUE(0).p;
    
    if(nargs==1){
        
        //create a gravity instance
        gravity_instance_t *instance=gravity_instance_new(vm, c);
        
        //allocate the U4DMatrix3n class-identity matrix
        U4DMatrix3n *r=new U4DMatrix3n();
        
        //set the cpp instance and xdata
        gravity_instance_setxdata(instance, r);
        
        RETURN_VALUE(VALUE_FROM_OBJECT(instance),rindex);
        
    }else if(nargs==10){
        
        RETURN_VALUE(VALUE_FROM_OBJECT(instance),rindex);
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Unable to create a U4DMatrix3n object.");
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

bool U4DScriptBindMatrix3n::matrix3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in matrix4n_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata
    U4DMatrix3n *r = (U4DMatrix3n *)instance->xdata;
    
    r->show();
    
    RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
    
}

bool U4DScriptBindMatrix3n::matrix3nTransformVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in matrix_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // check for optional parameters here (if you need to process a more complex constructor)
    if(nargs==2){
        
        gravity_value_t vectorValue=GET_VALUE(1);
        
        if (VALUE_ISA_INSTANCE(vectorValue)) {
            
            gravity_instance_t *vectorInstance=(gravity_instance_t*)vectorValue.p;
            
            U4DVector3n *v=(U4DVector3n*)vectorInstance->xdata;
            
            U4DMatrix3n *m = (U4DMatrix3n *)instance->xdata;
            
            U4DVector3n vTransformed=m->transform(*v);
            
            // create a new vector type
            U4DVector3n *r = new U4DVector3n(vTransformed.x, vTransformed.y, vTransformed.z);
            
            
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
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Unable to transform the vector. Make sure the vector is of type U4DVector3n.");
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

void U4DScriptBindMatrix3n::matrix3nFree(gravity_vm *vm, gravity_object_t *obj){
    
    gravity_instance_t *instance = (gravity_instance_t *)obj;
    
    // get xdata (which is a U4DMatrix3n instance)
    U4DMatrix3n *r = (U4DMatrix3n *)instance->xdata;
    
    // explicitly free memory
    delete r;
}

void U4DScriptBindMatrix3n::registerMatrix3nClasses(gravity_vm *vm){
    
    //create U4DMatrix3n class
    
    gravity_class_t *matrix3n_class = gravity_class_new_pair(vm, "U4DMatrix3n", NULL, 0, 0);
    gravity_class_t *matrix3n_class_meta = gravity_class_get_meta(matrix3n_class);
    
    gravity_class_bind(matrix3n_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(matrix3nCreate));
    gravity_class_bind(matrix3n_class, "show", NEW_CLOSURE_VALUE(matrix3nShow));
    
    gravity_class_bind(matrix3n_class, GRAVITY_OPERATOR_MUL_NAME, NEW_CLOSURE_VALUE(matrix3nTransformVector));
    
    // register U4DMatrix3n class inside VM
    gravity_vm_setvalue(vm, "U4DMatrix3n", VALUE_FROM_OBJECT(matrix3n_class));
    
    
}

}
