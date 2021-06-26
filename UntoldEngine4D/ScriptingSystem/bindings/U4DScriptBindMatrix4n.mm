//
//  U4DScriptBindMatrix4n.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/25/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindMatrix4n.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DScriptBindMatrix4n *U4DScriptBindMatrix4n::instance=0;

U4DScriptBindMatrix4n::U4DScriptBindMatrix4n(){
    
}

U4DScriptBindMatrix4n::~U4DScriptBindMatrix4n(){
    
}

U4DScriptBindMatrix4n *U4DScriptBindMatrix4n::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindMatrix4n(); 
    }
    
    return instance;
}

bool U4DScriptBindMatrix4n::matrix4nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    //self parameter is U4DMatrix4n class
    gravity_class_t *c=(gravity_class_t*)GET_VALUE(0).p;
    
    if(nargs==1){
        
        //create a gravity instance
        gravity_instance_t *instance=gravity_instance_new(vm, c);
        
        //allocate the U4DMatrix4n class-identity matrix
        U4DMatrix4n *r=new U4DMatrix4n();
        
        //set the cpp instance and xdata
        gravity_instance_setxdata(instance, r);
        
        RETURN_VALUE(VALUE_FROM_OBJECT(instance),rindex);
    }else if(nargs==17){
        
        RETURN_VALUE(VALUE_FROM_OBJECT(instance),rindex);
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("Unable to create a U4DMatrix4n class.");
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

bool U4DScriptBindMatrix4n::matrix4nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in matrix4n_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata
    U4DMatrix4n *r = (U4DMatrix4n *)instance->xdata;
    
    r->show();
    
    RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
    
}

void U4DScriptBindMatrix4n::matrix4nFree(gravity_vm *vm, gravity_object_t *obj){
    
}

void U4DScriptBindMatrix4n::registerMatrix4nClasses(gravity_vm *vm){
    
    //create U4DMatrix4n class
    
    gravity_class_t *matrix4n_class = gravity_class_new_pair(vm, "U4DMatrix4n", NULL, 0, 0);
    gravity_class_t *matrix4n_class_meta = gravity_class_get_meta(matrix4n_class);
    
    gravity_class_bind(matrix4n_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(matrix4nCreate));
    gravity_class_bind(matrix4n_class, "show", NEW_CLOSURE_VALUE(matrix4nShow));
    // register U4DMatrix4n class inside VM
    gravity_vm_setvalue(vm, "U4DMatrix4n", VALUE_FROM_OBJECT(matrix4n_class));
    
    
}

}
