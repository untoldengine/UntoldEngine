//
//  U4DScriptBindLogger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindLogger.h"

namespace U4DEngine {

U4DScriptBindLogger* U4DScriptBindLogger::instance=0;

U4DScriptBindLogger* U4DScriptBindLogger::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindLogger();
    }

    return instance;
}

U4DScriptBindLogger::U4DScriptBindLogger(){
    
}

U4DScriptBindLogger::~U4DScriptBindLogger(){
    
}

bool U4DScriptBindLogger::loggerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // self parameter is the logger_class create in register_cpp_classes
    gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
    
    // create Gravity instance and set its class to c
    gravity_instance_t *instance = gravity_instance_new(vm, c);
    
    // allocate a cpp instance of the logger class on the heap
    U4DLogger *logger = U4DLogger::sharedInstance();
    
    // set cpp instance and xdata of the gravity instance
    gravity_instance_setxdata(instance, logger);
    
    // return instance
    RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    
}

bool U4DScriptBindLogger::loggerLog(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in logger_create function
    //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
    //So for now, I'll just go through each argument and check the type
    U4DLogger *logger = U4DLogger::sharedInstance();
    
    gravity_value_t value=GET_VALUE(1);
    
    if (VALUE_ISA_INT(value)) {
        gravity_int_t v=value.n;
        logger->log("%d",v);
        
    }else if(VALUE_ISA_FLOAT(value)){
        gravity_float_t v=value.f;
        logger->log("%f",v);
        
    }else if(VALUE_ISA_STRING(value)){
        gravity_string_t *v=(gravity_string_t *)value.p;
        logger->log(v->s);
    }
        
    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
}

void U4DScriptBindLogger::loggerFree (gravity_vm *vm, gravity_object_t *obj){
    
}

void U4DScriptBindLogger::registerLoggerClasses (gravity_vm *vm){
    
    gravity_class_t *logger_class = gravity_class_new_pair(vm, "U4DLogger", NULL, 0, 0);
    gravity_class_t *logger_class_meta = gravity_class_get_meta(logger_class);
    
    gravity_class_bind(logger_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(loggerCreate));
    gravity_class_bind(logger_class, "log", NEW_CLOSURE_VALUE(loggerLog));
    
    // register logger class inside VM
    gravity_vm_setvalue(vm, "U4DLogger", VALUE_FROM_OBJECT(logger_class));
}

}
