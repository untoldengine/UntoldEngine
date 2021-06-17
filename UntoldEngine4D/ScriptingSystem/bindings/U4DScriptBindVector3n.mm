//
//  U4DScriptBindVector3n.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindVector3n.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DScriptBindVector3n* U4DScriptBindVector3n::instance=0;

U4DScriptBindVector3n* U4DScriptBindVector3n::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptBindVector3n();
    }

    return instance;
}

U4DScriptBindVector3n::U4DScriptBindVector3n(){
    
}

U4DScriptBindVector3n::~U4DScriptBindVector3n(){
    
}
// MARK: - Gravity Bridge -

bool U4DScriptBindVector3n::vector3nCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // self parameter is the u4dvector3n_class create in register_cpp_classes
    gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
    // check for optional parameters here (if you need to process a more complex constructor)
    
    if (nargs==4) {
    
        if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
            gravity_float_t v1 = GET_VALUE(1).f;
            gravity_float_t v2 = GET_VALUE(2).f;
            gravity_float_t v3 = GET_VALUE(3).f;
            
            // create Gravity instance and set its class to c
            gravity_instance_t *instance = gravity_instance_new(vm, c);
            
            // allocate a cpp instance of the vector class on the heap
            U4DVector3n *r = new U4DVector3n(v1,v2,v3);
            
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, r);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        }
    
    }
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    if (nargs!=4) {
        logger->log("A U4DVector3n requires three components.");
    }else{
        logger->log("The three vector components must be float types");
    }
    
    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
}

void U4DScriptBindVector3n::vector3nFree (gravity_vm *vm, gravity_object_t *obj){
    
    gravity_instance_t *instance = (gravity_instance_t *)obj;
    
    // get xdata (which is a vector3n instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;
    
    // explicitly free memory
    delete r;
    
}

void U4DScriptBindVector3n::registerVector3nClasses (gravity_vm *vm){
    
    //create vector3n class
    
    gravity_class_t *vector3n_class = gravity_class_new_pair(vm, "U4DVector3n", NULL, 0, 0);
    gravity_class_t *vector3n_class_meta = gravity_class_get_meta(vector3n_class);
    
    gravity_class_bind(vector3n_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(vector3nCreate));
    
    gravity_class_bind(vector3n_class, "x", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(xGet), NEW_FUNCTION(xSet))));
    gravity_class_bind(vector3n_class, "y", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(yGet), NEW_FUNCTION(ySet))));
    gravity_class_bind(vector3n_class, "z", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(zGet), NEW_FUNCTION(zSet))));
    
    gravity_class_bind(vector3n_class, "magnitude", NEW_CLOSURE_VALUE(vector3nMagnitude));
    gravity_class_bind(vector3n_class, "normalize", NEW_CLOSURE_VALUE(vector3nNormalize));
    gravity_class_bind(vector3n_class, "dot", NEW_CLOSURE_VALUE(vector3nDot));
    gravity_class_bind(vector3n_class, "cross", NEW_CLOSURE_VALUE(vector3nCross));
    
    gravity_class_bind(vector3n_class, "show", NEW_CLOSURE_VALUE(vector3nShow));
    
    gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_ADD_NAME, NEW_CLOSURE_VALUE(operatorVector3nAdd));
    gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_SUB_NAME, NEW_CLOSURE_VALUE(operatorVector3nSub));
    gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_MUL_NAME, NEW_CLOSURE_VALUE(operatorVector3nMul));
    gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_DIV_NAME, NEW_CLOSURE_VALUE(operatorVector3nDiv));
    
    // register vector3n class inside VM
    gravity_vm_setvalue(vm, "U4DVector3n", VALUE_FROM_OBJECT(vector3n_class));
    
}

bool U4DScriptBindVector3n::vector3nMagnitude (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
    
    // get self object which is the instance created in rect_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata (which is a cpp vector3n instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;
    
    // invoke the Area method
    double d = r->magnitude();
    
    RETURN_VALUE(VALUE_FROM_FLOAT(d), rindex);
}

bool U4DScriptBindVector3n::vector3nNormalize (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
    
    // get self object which is the instance created in rect_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata (which is a cpp vector instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;
    
    r->normalize();
    
    RETURN_VALUE(VALUE_FROM_OBJECT(r), rindex);
}

bool U4DScriptBindVector3n::vector3nDot(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
    
    // get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
    
    // dot product
    float d=(*vector1).dot(*(vector2));
    
    RETURN_VALUE(VALUE_FROM_FLOAT(d), rindex);
    
}

bool U4DScriptBindVector3n::vector3nCross(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
    
    // get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
    
    // add the vectors
    U4DVector3n v = (*vector1).cross(*(vector2));
    
    // create a new vector type
    U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);

    // lookup class "Vector3n" already registered inside the VM
    // a faster way would be to save a global variable of type gravity_class_t *
    // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

    // error not handled here but it should be checked
    gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

    // create a Vector3n instance
    gravity_instance_t *result = gravity_instance_new(vm, c);

    //setting the vector data to result
    gravity_instance_setxdata(result, r);

    RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
    
}

bool U4DScriptBindVector3n::vector3nShow (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in rect_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata (which is a cpp Rectangle instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;
    
    r->show();
    
    RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
}

bool U4DScriptBindVector3n::xGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;

     RETURN_VALUE(VALUE_FROM_FLOAT(r->x), rindex);
 }

bool U4DScriptBindVector3n::xSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
     U4DVector3n *r = (U4DVector3n *)instance->xdata;

     // read user value
     gravity_value_t value = GET_VALUE(1);

     // decode value
     double d = 0.0f;
     if (VALUE_ISA_FLOAT(value)) d = VALUE_AS_FLOAT(value);
     else if (VALUE_ISA_INT(value)) d = double(VALUE_AS_INT(value));
     // more cases here, for example VALUE_ISA_STRING

     r->x = d;

     RETURN_NOVALUE();
 }

bool U4DScriptBindVector3n::yGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;

     RETURN_VALUE(VALUE_FROM_FLOAT(r->y), rindex);
 }

bool U4DScriptBindVector3n::ySet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
     U4DVector3n *r = (U4DVector3n *)instance->xdata;

     // read user value
     gravity_value_t value = GET_VALUE(1);

     // decode value
     double d = 0.0f;
     if (VALUE_ISA_FLOAT(value)) d = VALUE_AS_FLOAT(value);
     else if (VALUE_ISA_INT(value)) d = double(VALUE_AS_INT(value));
     // more cases here, for example VALUE_ISA_STRING

     r->y = d;

     RETURN_NOVALUE();
 }


bool U4DScriptBindVector3n::zGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
    U4DVector3n *r = (U4DVector3n *)instance->xdata;

     RETURN_VALUE(VALUE_FROM_FLOAT(r->z), rindex);
 }

bool U4DScriptBindVector3n::zSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
     // get self object which is the instance created in rect_create function
     gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

     // get xdata (which is a cpp Rectangle instance)
     U4DVector3n *r = (U4DVector3n *)instance->xdata;

     // read user value
     gravity_value_t value = GET_VALUE(1);

     // decode value
     double d = 0.0f;
     if (VALUE_ISA_FLOAT(value)) d = VALUE_AS_FLOAT(value);
     else if (VALUE_ISA_INT(value)) d = double(VALUE_AS_INT(value));
     // more cases here, for example VALUE_ISA_STRING

     r->z = d;

     RETURN_NOVALUE();
 }

bool U4DScriptBindVector3n::operatorVector3nAdd (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
    
    // get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
    
    // add the vectors
    U4DVector3n v = *vector1 + *vector2;
    
    // create a new vector type
    U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);

    // lookup class "Vector3n" already registered inside the VM
    // a faster way would be to save a global variable of type gravity_class_t *
    // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

    // error not handled here but it should be checked
    gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

    // create a Vector3n instance
    gravity_instance_t *result = gravity_instance_new(vm, c);

    //setting the vector data to result
    gravity_instance_setxdata(result, r);

    RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
}

bool U4DScriptBindVector3n::operatorVector3nSub (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
    
    // subtract the vectors
    U4DVector3n v = *vector1 - *vector2;
    
    // create a new vector type
    U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);

    // lookup class "Vector3n" already registered inside the VM
    // a faster way would be to save a global variable of type gravity_class_t *
    // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

    // error not handled here but it should be checked
    gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

    // create a Vector3n instance
    gravity_instance_t *result = gravity_instance_new(vm, c);

    //setting the vector data to result
    gravity_instance_setxdata(result, r);

    RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
    
}

bool U4DScriptBindVector3n::operatorVector3nMul (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    /// get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    
    gravity_float_t scalar = GET_VALUE(1).f;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    
    //add the vectors
    U4DVector3n v=*vector1*scalar;
    
    // create a new vector type
    U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);

    // lookup class "Vector3n" already registered inside the VM
    // a faster way would be to save a global variable of type gravity_class_t *
    // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

    // error not handled here but it should be checked
    gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

    // create a Vector3n instance
    gravity_instance_t *result = gravity_instance_new(vm, c);

    //setting the vector data to result
    gravity_instance_setxdata(result, r);

    RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
}

bool U4DScriptBindVector3n::operatorVector3nDiv (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    /// get the two vector arguments
    gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
    
    gravity_float_t scalar = GET_VALUE(1).f;
    
    // get xdata for both vectors
    U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
    
    //add the vectors
    U4DVector3n v=*vector1/scalar;
    
    // create a new vector type
    U4DVector3n *r = new U4DVector3n(v.x, v.y, v.z);

    // lookup class "Vector3n" already registered inside the VM
    // a faster way would be to save a global variable of type gravity_class_t *
    // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

    // error not handled here but it should be checked
    gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

    // create a Vector3n instance
    gravity_instance_t *result = gravity_instance_new(vm, c);

    //setting the vector data to result
    gravity_instance_setxdata(result, r);

    RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
}

}
