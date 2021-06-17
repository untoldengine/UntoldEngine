//
//  U4DScriptBindCamera.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindCamera.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DScriptBindCamera* U4DScriptBindCamera::instance=0;

U4DScriptBindCamera* U4DScriptBindCamera::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindCamera();
    }

    return instance;
}

U4DScriptBindCamera::U4DScriptBindCamera(){
    
}

U4DScriptBindCamera::~U4DScriptBindCamera(){
    
}

bool U4DScriptBindCamera::cameraCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // self parameter is the rect_class create in register_cpp_classes
    gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
    
    // create Gravity instance and set its class to c
    gravity_instance_t *instance = gravity_instance_new(vm, c);
    
    // allocate a cpp instance of the camera class on the heap
    U4DCamera *camera = U4DCamera::sharedInstance();
    
    // set cpp instance and xdata of the gravity instance
    gravity_instance_setxdata(instance, camera);
    
    // return instance
    RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    
}

bool U4DScriptBindCamera::cameraTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in camera_create function
    //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // check for optional parameters here (if you need to process a more complex constructor)
    if (nargs==4) {
    
        if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
            
            gravity_float_t v1 = GET_VALUE(1).f;
            gravity_float_t v2 = GET_VALUE(2).f;
            gravity_float_t v3 = GET_VALUE(3).f;
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            
            camera->translateTo(v1, v2, v3);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    if (nargs!=4) {
        logger->log("A translation requires three components.");
    }else{
        logger->log("The three components must be float types");
    }
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

bool U4DScriptBindCamera::cameraTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in camera_create function
    //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // check for optional parameters here (if you need to process a more complex constructor)
    if (nargs==4) {
    
        if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
            
            gravity_float_t v1 = GET_VALUE(1).f;
            gravity_float_t v2 = GET_VALUE(2).f;
            gravity_float_t v3 = GET_VALUE(3).f;
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            
            camera->translateBy(v1, v2, v3);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    if (nargs!=4) {
        logger->log("A translation requires three components.");
    }else{
        logger->log("The three components must be float types");
    }
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
}

bool U4DScriptBindCamera::cameraRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in camera_create function
    //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // check for optional parameters here (if you need to process a more complex constructor)
    if (nargs==4) {
    
        if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
            
            gravity_float_t v1 = GET_VALUE(1).f;
            gravity_float_t v2 = GET_VALUE(2).f;
            gravity_float_t v3 = GET_VALUE(3).f;
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            
            camera->rotateTo(v1, v2, v3);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    if (nargs!=4) {
        logger->log("A rotation requires three components.");
    }else{
        logger->log("The three components must be float types");
    }
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
}

bool U4DScriptBindCamera::cameraRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in camera_create function
    //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // check for optional parameters here (if you need to process a more complex constructor)
    if (nargs==4) {
    
        if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
            
            gravity_float_t v1 = GET_VALUE(1).f;
            gravity_float_t v2 = GET_VALUE(2).f;
            gravity_float_t v3 = GET_VALUE(3).f;
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            
            camera->rotateBy(v1, v2, v3);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    if (nargs!=4) {
        logger->log("A rotation requires three components.");
    }else{
        logger->log("The three components must be float types");
    }
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
}

void U4DScriptBindCamera::cameraFree (gravity_vm *vm, gravity_object_t *obj){
    
}

void U4DScriptBindCamera::registerCameraClasses (gravity_vm *vm){
    
    gravity_class_t *camera_class = gravity_class_new_pair(vm, "U4DCamera", NULL, 0, 0);
    gravity_class_t *camera_class_meta = gravity_class_get_meta(camera_class);
    
    gravity_class_bind(camera_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(cameraCreate));
    
    gravity_class_bind(camera_class, "translateTo", NEW_CLOSURE_VALUE(cameraTranslateTo));
    gravity_class_bind(camera_class, "translateBy", NEW_CLOSURE_VALUE(cameraTranslateBy));
    gravity_class_bind(camera_class, "rotateTo", NEW_CLOSURE_VALUE(cameraRotateTo));
    gravity_class_bind(camera_class, "rotateBy", NEW_CLOSURE_VALUE(cameraRotateBy));
    
    // register logger class inside VM
    gravity_vm_setvalue(vm, "U4DCamera", VALUE_FROM_OBJECT(camera_class));
}

}
