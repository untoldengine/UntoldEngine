//
//  U4DScriptManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptManager.h"
#include <list>
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DCamera.h"
#include "U4DGameConfigs.h"
#include "U4DScriptBridge.h"

namespace U4DEngine {

    U4DScriptManager* U4DScriptManager::instance=0;

    U4DScriptManager* U4DScriptManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptManager();
        }

        return instance;
    }

    U4DScriptManager::U4DScriptManager(){
     
        //initialize script manager
        init();
    }

    U4DScriptManager::~U4DScriptManager(){
        
    }

    bool U4DScriptManager::bridgeInstance(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
         // self parameter is the scriptBrige_class create in register_cpp_classes
         gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;

         // create Gravity instance and set its class to c
         gravity_instance_t *instance = gravity_instance_new(vm, c);

         // allocate a cpp instance of the logger class on the heap
         U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

         // set cpp instance and xdata of the gravity instance
         gravity_instance_setxdata(instance, scriptBridge);

         // return instance
         RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);

        
    }
    
    //Vector3n
    bool U4DScriptManager::vector3nNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::vector3nMagnitude(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
        // get self object which is the instance created in rect_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata (which is a cpp vector3n instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;
        
        // invoke the Area method
        double d = r->magnitude();
        
        RETURN_VALUE(VALUE_FROM_FLOAT(d), rindex);
    }

    bool U4DScriptManager::vector3nNormalize (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
        // get self object which is the instance created in rect_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata (which is a cpp vector instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;
        
        r->normalize();
        
        RETURN_VALUE(VALUE_FROM_OBJECT(r), rindex);
    }

    bool U4DScriptManager::vector3nDot(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
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

    bool U4DScriptManager::vector3nCross(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
        // get the two vector arguments
        gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
        
        // get xdata for both vectors
        U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
        U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
        
        // cross the vectors
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

    bool U4DScriptManager::vector3nAngle(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get the two vector arguments
        gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_instance_t *v2 = (gravity_instance_t *)GET_VALUE(1).p;
        
        // get xdata for both vectors
        U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
        U4DVector3n *vector2 = (U4DVector3n *)v2->xdata;
        
        // get the angle
        float angle = (*vector1).angle(*(vector2));

        RETURN_VALUE(VALUE_FROM_FLOAT(angle), rindex);
        
    }

    bool U4DScriptManager::vector3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in rect_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DVector3n *r = (U4DVector3n *)instance->xdata;
        
        r->show();
        
        RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
    }

    bool U4DScriptManager::xGet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
         // get self object which is the instance created in rect_create function
         gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

         // get xdata (which is a cpp Rectangle instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;

         RETURN_VALUE(VALUE_FROM_FLOAT(r->x), rindex);
     }

    bool U4DScriptManager::xSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
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

    bool U4DScriptManager::yGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
         // get self object which is the instance created in rect_create function
         gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

         // get xdata (which is a cpp Rectangle instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;

         RETURN_VALUE(VALUE_FROM_FLOAT(r->y), rindex);
     }

    bool U4DScriptManager::ySet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
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


    bool U4DScriptManager::zGet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
         // get self object which is the instance created in rect_create function
         gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

         // get xdata (which is a cpp Rectangle instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;

         RETURN_VALUE(VALUE_FROM_FLOAT(r->z), rindex);
     }

    bool U4DScriptManager::zSet (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
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

    bool U4DScriptManager::vector3nAdd (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
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

    bool U4DScriptManager::vector3nSub (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::vector3nMul (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        /// get the two vector arguments
        gravity_instance_t *v1 = (gravity_instance_t *)GET_VALUE(0).p;
        
        gravity_float_t scalar = GET_VALUE(1).f;
        
        // get xdata for both vectors
        U4DVector3n *vector1 = (U4DVector3n *)v1->xdata;
        
        //multiply the vectors
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

    bool U4DScriptManager::vector3nDiv (gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    void U4DScriptManager::vector3nFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a vector3n instance)
        U4DVector3n *r = (U4DVector3n *)instance->xdata;
        
        // explicitly free memory
        delete r;
        
    }

    //Matrix3n

    bool U4DScriptManager::matrix3nNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::matrix3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in matrix4n_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DMatrix3n *r = (U4DMatrix3n *)instance->xdata;
        
        r->show();
        
        RETURN_VALUE(VALUE_FROM_BOOL(true), rindex);
        
    }

    bool U4DScriptManager::matrix3nTransformVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    void U4DScriptManager::matrix3nFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a U4DMatrix3n instance)
        U4DMatrix3n *r = (U4DMatrix3n *)instance->xdata;
        
        // explicitly free memory
        delete r;
    }

    //logger
    bool U4DScriptManager::loggerNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::loggerLog(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    void U4DScriptManager::loggerFree (gravity_vm *vm, gravity_object_t *obj){
        
    }
    
    //MARK: -Model Class-
    bool U4DScriptManager::loadModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t assetName=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(assetName)) {
                
                gravity_string_t *v=(gravity_string_t *)assetName.p;
                std::string name(v->s);
                
                std::string entityName=scriptBridge->loadModel(name);
                
                gravity_value_t gravityEntityName = VALUE_FROM_CSTRING(NULL, entityName.c_str());
                gravity_string_t *n=(gravity_string_t *)gravityEntityName.p;
                
                RETURN_VALUE(VALUE_FROM_STRING(vm, n->s, n->len),rindex);
                
            }
            
        }else if(nargs==3){
            
            gravity_value_t assetName=GET_VALUE(1);
            gravity_value_t pipelineName=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(assetName) && VALUE_ISA_STRING(pipelineName)) {
                
                gravity_string_t *v=(gravity_string_t *)assetName.p;
                std::string name(v->s);
                
                gravity_string_t *pipe=(gravity_string_t *)pipelineName.p;
                std::string pipeline(pipe->s);
                
                std::string entityName=scriptBridge->loadModel(name,pipeline);
                
                gravity_value_t gravityEntityName = VALUE_FROM_CSTRING(NULL, entityName.c_str());
                gravity_string_t *n=(gravity_string_t *)gravityEntityName.p;
                
                RETURN_VALUE(VALUE_FROM_STRING(vm, n->s, n->len),rindex);
                
            }
        }
        
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::addChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        gravity_value_t entityName=GET_VALUE(1);
        gravity_value_t parentEntityName=GET_VALUE(2);
        
        if (VALUE_ISA_STRING(entityName) && VALUE_ISA_STRING(parentEntityName)) {
            
            gravity_string_t *v=(gravity_string_t *)entityName.p;
            std::string childName(v->s); //child name
            
            gravity_string_t *p=(gravity_string_t *)parentEntityName.p;
            std::string parentName(p->s); //parent anme
            
            scriptBridge->addChild(childName,parentName);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::removeChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        gravity_value_t entityName=GET_VALUE(1);
        
        if (VALUE_ISA_STRING(entityName)) {
            
            gravity_string_t *v=(gravity_string_t *)entityName.p;
            std::string childName(v->s); //child name
            
            scriptBridge->removeChild(childName);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::translateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        // get self object which is the instance created in create function
        //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
             //So for now, I'll just go through each argument and check the type
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *positionValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (positionValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *position = (U4DVector3n *)positionValue->xdata;
                    
                scriptBridge->translateTo(name, *position);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                 
            }
            
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::translateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        // get self object which is the instance created in create function
        //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
             //So for now, I'll just go through each argument and check the type
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *positionValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (positionValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *position = (U4DVector3n *)positionValue->xdata;
                    
                scriptBridge->translateBy(name, *position);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                 
            }
            
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    //rotate
    bool U4DScriptManager::rotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        // get self object which is the instance created in create function
        //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
             //So for now, I'll just go through each argument and check the type
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *rotateValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (rotateValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *orientation = (U4DVector3n *)rotateValue->xdata;
                    
                scriptBridge->rotateTo(name, *orientation);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                 
            }
            
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::rotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        // get self object which is the instance created in create function
        //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
             //So for now, I'll just go through each argument and check the type
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *rotateValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (rotateValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *orientation = (U4DVector3n *)rotateValue->xdata;
                    
                scriptBridge->rotateBy(name, *orientation);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
            }
            
        }else if (nargs==4) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t angle=GET_VALUE(2);
            gravity_instance_t *axisValue = (gravity_instance_t *)GET_VALUE(3).p;
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_FLOAT(angle) && (axisValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_float_t angleValue=angle.f;
                
                U4DVector3n *axis = (U4DVector3n *)axisValue->xdata;
                    
                scriptBridge->rotateBy(name,angleValue, *axis);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                 
            }
            
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::getAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n absolutePosition=scriptBridge->getAbsolutePosition(name);
                
                //convert the vector to a list
                
//                //create a new list
//                gravity_list_t *l=gravity_list_new(NULL, 3);
//
//                //load the vector components into the list
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.x));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.y));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.z));
//
//                // transfer newly allocated object to the VM
//                gravity_vm_transfer(vm, (gravity_object_t*) l);
//
//                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(absolutePosition.x, absolutePosition.y, absolutePosition.z);

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
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::getAbsoluteOrientation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n absoluteOrientation=scriptBridge->getAbsoluteOrientation(name);
                
                //convert the vector to a list
                
                //create a new list
//                gravity_list_t *l=gravity_list_new(NULL, 3);
//
//                //load the vector components into the list
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.x));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.y));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.z));
//
//                // transfer newly allocated object to the VM
//                gravity_vm_transfer(vm, (gravity_object_t*) l);
//
//                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(absoluteOrientation.x, absoluteOrientation.y, absoluteOrientation.z);

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
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::getViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n viewDirection=scriptBridge->getViewInDirection(name);
                
                //convert the vector to a list
                
//                //create a new list
//                gravity_list_t *l=gravity_list_new(NULL, 3);
//
//                //load the vector components into the list
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.x));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.y));
//                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.z));
//
//                // transfer newly allocated object to the VM
//                gravity_vm_transfer(vm, (gravity_object_t*) l);
//
//                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(viewDirection.x, viewDirection.y, viewDirection.z);

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
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *viewDirectionValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (viewDirectionValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *viewDirection = (U4DVector3n *)viewDirectionValue->xdata;
                    
                //move in direction
                scriptBridge->setViewInDirection(name, *viewDirection);
                
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
                    
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setEntityForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *viewDirection = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (viewDirection!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *direction = (U4DVector3n *)viewDirection->xdata;
                
                //move in direction
                scriptBridge->setEntityForwardVector(name, *direction);
                
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
                    
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::initPhysics(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==2) {
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                
                std::string name(v->s);
                
                //check if the
                scriptBridge->initPhysics(name); 
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::deinitPhysics(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==2) {
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                
                std::string name(v->s);
                
                //check if the
                scriptBridge->deinitPhysics(name);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }
        

    bool U4DScriptManager::applyVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==4) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *velocityValue = (gravity_instance_t *)GET_VALUE(2).p;
            gravity_value_t dtValue=GET_VALUE(3);
            
            if (VALUE_ISA_STRING(entity) && (velocityValue!=nullptr) && VALUE_ISA_FLOAT(dtValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_float_t dt=dtValue.f;
                
                U4DVector3n *velocity = (U4DVector3n *)velocityValue->xdata;
                    
                scriptBridge->applyVelocity(name, *velocity,dt);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }
    
    bool U4DScriptManager::setGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *gravityValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (gravityValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *gravity = (U4DVector3n *)gravityValue->xdata;
                    
                scriptBridge->setGravity(name, *gravity);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                
            }
            
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::setCollisionFilterCategory(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t category=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_INT(category)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_int_t collisionCategory=category.n;
                
                scriptBridge->setCollisionFilterCategory(name, (int)collisionCategory);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setCollisionFilterMask(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t mask=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_INT(mask)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_int_t collisionMask=mask.n;
                
                scriptBridge->setCollisionFilterMask(name, (int)collisionMask);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setIsCollisionSensor(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t value=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_BOOL(value)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                bool sensorValue=VALUE_AS_BOOL(value);
                
                scriptBridge->setIsCollisionSensor(name, sensorValue);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setCollidingTag(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t tag=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(tag)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_string_t *t=(gravity_string_t *)tag.p;
                std::string collisionTag(t->s);
                
                scriptBridge->setCollidingTag(name, collisionTag);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::getModelHasCollided(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                bool collided=scriptBridge->getModelHasCollided(name);
                
                RETURN_VALUE(VALUE_FROM_BOOL(collided),rindex);
                
            }
        
        }
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::getCollisionListTags(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                std::list<std::string> collidingList=scriptBridge->getCollisionListTags(name);
                
                //convert c++ list to gravity list
                //create a new list
                gravity_list_t *l=gravity_list_new(NULL, (int)collidingList.size());
                
                for(auto const &n:collidingList){
                    
                    gravity_value_t collidingModelTag=VALUE_FROM_CSTRING(vm, n.c_str());
                    
                    //load the vector components into the list
                    marray_push(gravity_value_t, l->array, collidingModelTag);
                    
                }
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
            }
        
        }
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::initMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t massValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_FLOAT(massValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_float_t mass=massValue.f;
                
                scriptBridge->initMass(name, mass);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
        
    }

bool U4DScriptManager::initAsPlatform(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
    
    if(nargs==3){
        
        gravity_value_t entity=GET_VALUE(1);
        gravity_value_t value=GET_VALUE(2);
        
        if (VALUE_ISA_STRING(entity) && VALUE_ISA_BOOL(value)) {
            
            gravity_string_t *v=(gravity_string_t *)entity.p;
            std::string name(v->s);
            
            bool isPlatform=VALUE_AS_BOOL(value);
            
            scriptBridge->initAsPlatform(name, isPlatform);
            
            RETURN_VALUE(VALUE_FROM_TRUE, rindex);
        }
        
    }
    
    RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    
}

    bool U4DScriptManager::resumeCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                scriptBridge->resumeCollisionBehavior(name);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
            
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::pauseCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==2){
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                scriptBridge->pauseCollisionBehavior(name);
                
                RETURN_VALUE(VALUE_FROM_TRUE, rindex);
            }
        
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
        
    }

    bool U4DScriptManager::initAnimations(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        std::list<std::string> animationList;
        
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
               
                for (int i=0; i<count; i++) {
                    
                    gravity_string_t *anim=(gravity_string_t *)(marray_get(list->array,i)).p; 
                    std::string animName(anim->s);
                    
                    animationList.push_back(animName);
                    
                }
            
                //init animation manager with animations
                scriptBridge->initAnimations(name, animationList);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::deinitAnimations(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==2) {
            
            gravity_value_t entity=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                
                std::string name(v->s);
                
                //check if the
                scriptBridge->deinitAnimations(name);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::playAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t animation=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(animation)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string name(e->s);
                
                gravity_string_t *a=(gravity_string_t *)animation.p;
                std::string animationName(a->s);
                
                scriptBridge->playAnimation(name, animationName);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::stopAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t animation=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(animation)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string name(e->s);
                
                gravity_string_t *a=(gravity_string_t *)animation.p;
                std::string animationName(a->s);
                
                scriptBridge->stopAnimation(name, animationName);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::getAnimationIsPlaying(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t animation=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(animation)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string name(e->s);
                
                gravity_string_t *a=(gravity_string_t *)animation.p;
                std::string animationName(a->s);
                
                bool isPlaying=scriptBridge->getAnimationIsPlaying(name, animationName);
                
                RETURN_VALUE(VALUE_FROM_BOOL(isPlaying),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::getCurrentKeyframe(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t animation=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(animation)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string name(e->s);
                
                gravity_string_t *a=(gravity_string_t *)animation.p;
                std::string animationName(a->s);
                
                int currentKeyframe=scriptBridge->getCurrentKeyframe(name, animationName);
                
                RETURN_VALUE(VALUE_FROM_INT(currentKeyframe),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    

    bool U4DScriptManager::setPlayContinuousLoop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==4){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t animation=GET_VALUE(2);
            gravity_value_t value=GET_VALUE(3);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(animation) && VALUE_ISA_BOOL(value)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string name(e->s);
                
                gravity_string_t *a=(gravity_string_t *)animation.p;
                std::string animationName(a->s);
                
                bool playContinuously=VALUE_AS_BOOL(value);
                
                scriptBridge->setPlayContinuousLoop(name, animationName,playContinuously);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::setEntityToArmatureBoneSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==4){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t actor=GET_VALUE(2);
            gravity_value_t bone=GET_VALUE(3);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(actor) && VALUE_ISA_STRING(bone)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string entityName(e->s);
                
                gravity_string_t *a=(gravity_string_t *)actor.p;
                std::string actorName(a->s);
                
                gravity_string_t *b=(gravity_string_t *)bone.p;
                std::string boneName(b->s);
                
                scriptBridge->setEntityToArmatureBoneSpace(entityName, actorName, boneName);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::setEntityToAnimationBoneSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==5){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t actor=GET_VALUE(2);
            gravity_value_t animation=GET_VALUE(3);
            gravity_value_t bone=GET_VALUE(4);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(actor) && VALUE_ISA_STRING(animation) && VALUE_ISA_STRING(bone)){
                
                gravity_string_t *e=(gravity_string_t *)entity.p;
                std::string entityName(e->s);
                
                gravity_string_t *a=(gravity_string_t *)actor.p;
                std::string actorName(a->s);
                
                gravity_string_t *anim=(gravity_string_t *)animation.p;
                std::string animName(anim->s);
                
                gravity_string_t *b=(gravity_string_t *)bone.p;
                std::string boneName(b->s);
                
                scriptBridge->setEntityToAnimationBoneSpace(entityName, actorName, animName, boneName);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::seek(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *targetPos = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (targetPos!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *targetPosition = (U4DVector3n *)targetPos->xdata;
                    
                
                //compute the final velocity
                U4DVector3n finalVelocity=scriptBridge->seek(name, *targetPosition);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(finalVelocity.x, finalVelocity.y, finalVelocity.z);

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
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
        
    }

    bool U4DScriptManager::arrive(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *targetPos = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (targetPos!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *targetPosition = (U4DVector3n *)targetPos->xdata;
                    
                //compute the final velocity
                U4DVector3n finalVelocity=scriptBridge->arrive(name, *targetPosition);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(finalVelocity.x, finalVelocity.y, finalVelocity.z);

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
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
        
    }

    bool U4DScriptManager::pursuit(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t evaderEntity=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_STRING(evaderEntity)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_string_t *n=(gravity_string_t *)evaderEntity.p;
                std::string evaderName(n->s);
                
                //compute the final velocity
                U4DVector3n finalVelocity=scriptBridge->pursuit(name, evaderName);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(finalVelocity.x, finalVelocity.y, finalVelocity.z);

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
            
        }else{
            U4DLogger *logger = U4DLogger::sharedInstance();
            logger->log("The names for the pursuer and evader must be in string format");
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }
 
    //camera
    bool U4DScriptManager::cameraNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::cameraTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::cameraTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::cameraRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    bool U4DScriptManager::cameraRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    void U4DScriptManager::cameraFree (gravity_vm *vm, gravity_object_t *obj){
        
    }

    bool U4DScriptManager::setCameraAsThirdPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
                
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                scriptBridge->setCameraAsThirdPerson(name, *offset);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::setCameraAsFirstPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
                
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                scriptBridge->setCameraAsFirstPerson(name, *offset);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::setCameraAsBasicFollow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
                
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            if (VALUE_ISA_STRING(entity) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                scriptBridge->setCameraAsBasicFollow(name, *offset);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::pauseScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        scriptBridge->pauseScene();
        
        RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        
    }

    bool U4DScriptManager::playScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        scriptBridge->playScene();
        
        RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        
    }
    

    bool U4DScriptManager::anchorMouse(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==2) {
            gravity_value_t value=GET_VALUE(1);
            
            if (VALUE_ISA_BOOL(value)) {
                
                bool shouldAnchor=VALUE_AS_BOOL(value);
                scriptBridge->anchorMouse(shouldAnchor);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    void U4DScriptManager::awakeClosure(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t awake_function = gravity_vm_getvalue(vm, "awake", (uint32_t)strlen("awake"));
            if (!VALUE_ISA_CLOSURE(awake_function)) {
                printf("Unable to find awake function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *awake_closure = VALUE_AS_CLOSURE(awake_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, awake_closure, VALUE_FROM_NULL, 0, 0)) {
                    
                    // retrieve returned result
                    gravity_value_t result = gravity_vm_result(vm);
                    
                    
                    
                }
            }
            
        }
        
    }

    void U4DScriptManager::initClosure(){
    
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t init_function = gravity_vm_getvalue(vm, "init", (uint32_t)strlen("init"));
            if (!VALUE_ISA_CLOSURE(init_function)) {
                printf("Unable to find init function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *init_closure = VALUE_AS_CLOSURE(init_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, init_closure, VALUE_FROM_NULL, 0, 0)) {
                    
                    // retrieve returned result
                    gravity_value_t result = gravity_vm_result(vm);
                    
                    
                    
                }
            }
            
        }
        
    }

    void U4DScriptManager::deInitClosure(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t deInit_function = gravity_vm_getvalue(vm, "deinit", (uint32_t)strlen("deinit"));
            if (!VALUE_ISA_CLOSURE(deInit_function)) {
                printf("Unable to find deinit function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *deInit_closure = VALUE_AS_CLOSURE(deInit_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, deInit_closure, VALUE_FROM_NULL, 0, 0)) {
                    
                    // retrieve returned result
                    gravity_value_t result = gravity_vm_result(vm);
                    
                    
                    
                }
            
            }
            
        }
        
    }

    void U4DScriptManager::preUpdateClosure(double dt){
        
        U4DDirector *director=U4DDirector::sharedInstance();

        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){

            gravity_value_t pre_update_function = gravity_vm_getvalue(vm, "preUpdate", (uint32_t)strlen("preUpdate"));
            if (!VALUE_ISA_CLOSURE(pre_update_function)) {
                printf("Unable to find update function into Gravity VM.\n");

            }else{

                // convert function to closure
                gravity_closure_t *pre_update_closure = VALUE_AS_CLOSURE(pre_update_function);

                // prepare parameters

                gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
                gravity_value_t params[] = {p1};

                // execute init closure
                if (gravity_vm_runclosure (vm, pre_update_closure, VALUE_FROM_NULL, params, 1)) {
                    
                }
            }
        }
        
    }

    void U4DScriptManager::updateClosure(double dt){ 

         U4DDirector *director=U4DDirector::sharedInstance();

         if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){

             gravity_value_t update_function = gravity_vm_getvalue(vm, "update", (uint32_t)strlen("update"));
             if (!VALUE_ISA_CLOSURE(update_function)) {
                 printf("Unable to find update function into Gravity VM.\n");

             }else{

                 // convert function to closure
                 gravity_closure_t *update_closure = VALUE_AS_CLOSURE(update_function);

                 // prepare parameters

                 gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
                 gravity_value_t params[] = {p1};

                 // execute init closure
                 if (gravity_vm_runclosure (vm, update_closure, VALUE_FROM_NULL, params, 1)) {
                     
                 }
             }
         }
     }

    void U4DScriptManager::userInputClosure(void *uData){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){
                    
            gravity_value_t userInput_function = gravity_vm_getvalue(vm, "userInput", (uint32_t)strlen("userInput"));
            if (!VALUE_ISA_CLOSURE(userInput_function)) {
                printf("Unable to find user-input function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *userInput_closure = VALUE_AS_CLOSURE(userInput_function);
                
             U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;

             
             //set the value to each key in the map
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[inputElementType],VALUE_FROM_INT(controllerInputMessage.inputElementType));

             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[inputElementAction],VALUE_FROM_INT(controllerInputMessage.inputElementAction));

             //joystick
             //prepare joystick data into a list before inserting it into a map
             gravity_value_t joystickDirX = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.x);
             gravity_value_t joystickDirY = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.y);
             
            marray_push(gravity_value_t, joystickDirectionList->array, joystickDirX);
            marray_push(gravity_value_t, joystickDirectionList->array, joystickDirY);
             
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[joystickDirection],VALUE_FROM_OBJECT(joystickDirectionList));
                
             //inputposition
             gravity_value_t inputPositionX = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.x);
             gravity_value_t inputPositionY = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.y);
             
            marray_push(gravity_value_t, inputPositionList->array, inputPositionX);
            marray_push(gravity_value_t, inputPositionList->array, inputPositionY);
                
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[inputPosition],VALUE_FROM_OBJECT(inputPositionList));

             //previousMousePosition
             gravity_value_t previousMousePositionX = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.x);
             gravity_value_t previousMousePositionY = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.y);
             
            marray_push(gravity_value_t, previousMousePositionList->array, previousMousePositionX);
            marray_push(gravity_value_t, previousMousePositionList->array, previousMousePositionY);

             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[previousMousePosition],VALUE_FROM_OBJECT(previousMousePositionList));

             //mouseDeltaPosition
             gravity_value_t mouseDeltaPositionX = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.x);
             gravity_value_t mouseDeltaPositionY = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.y);
             
            marray_push(gravity_value_t, mouseDeltaPositionList->array, mouseDeltaPositionX);
            marray_push(gravity_value_t, mouseDeltaPositionList->array, mouseDeltaPositionY);

             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[mouseDeltaPosition],VALUE_FROM_OBJECT(mouseDeltaPositionList));

             //joystickChangeDirection
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[joystickChangeDirection],VALUE_FROM_BOOL(controllerInputMessage.joystickChangeDirection));

             //mouseChangeDirection
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[mouseChangeDirection],VALUE_FROM_BOOL(controllerInputMessage.mouseChangeDirection));

             //arrowKeyDirection
             gravity_value_t arrowKeyDirectionX = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.x);
             gravity_value_t arrowKeyDirectionY = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.y);
             
            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionX);
            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionY);

             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[arrowKeyDirection],VALUE_FROM_OBJECT(arrowKeyDirectionList));


             //elementUIName
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[elementUIName],VALUE_FROM_STRING(vm, controllerInputMessage.elementUIName.c_str(), (int)controllerInputMessage.elementUIName.length()));

             //dataValue
             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[dataValue],VALUE_FROM_FLOAT(controllerInputMessage.dataValue));


             gravity_value_t controllerInputData=VALUE_FROM_OBJECT(controllerInputMessageMap);
             gravity_value_t params[] = {controllerInputData};

             // execute user-input closure
             if (gravity_vm_runclosure (vm, userInput_closure, VALUE_FROM_NULL, params, 1)) {}

            }
        
        }
        
        removeItemsInList(joystickDirectionList);
        removeItemsInList(inputPositionList);
        removeItemsInList(previousMousePositionList);
        removeItemsInList(mouseDeltaPositionList);
        removeItemsInList(arrowKeyDirectionList);
        
        //remove keys and values from map
        for(auto n:userInputElementArray){
            gravity_hash_remove(controllerInputMessageMap->hash, n);
        }
        
        
    }

    void U4DScriptManager::loadGameConfigs(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t init_function = gravity_vm_getvalue(vm, "loadConfigs", (uint32_t)strlen("loadConfigs"));
            if (!VALUE_ISA_CLOSURE(init_function)) {
                printf("Unable to find init function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *init_closure = VALUE_AS_CLOSURE(init_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, init_closure, VALUE_FROM_NULL, 0, 0)) {
                    
                    // retrieve returned result
                    gravity_value_t result = gravity_vm_result(vm);
                    
                    if(VALUE_ISA_MAP(result)){
                                            
                        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
                        
                        gravity_map_t *map = VALUE_AS_MAP(result);
                        
                        std::map<std::string,float>::iterator it=gameConfigs->configsMap.begin();
                        
                        //iterate over the map
                        while (it!=gameConfigs->configsMap.end()) {
                            
                            //Access key from first element
                            std::string paramKeyName=it->first;
                            
                            gravity_value_t gravityParamKey = VALUE_FROM_CSTRING(NULL, paramKeyName.c_str());
                        
                            gravity_value_t *gravityValue = gravity_hash_lookup(map->hash, gravityParamKey); 
                            
                            gravity_float_t v=gravityValue->f;
                            
                            it->second=v;
                            
                            it++;
                        }
     
                    }
                    
                }
            }
            
        }
        
    }

    bool U4DScriptManager::loadScript(std::string uScriptPath){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        logger->log("Loading script %s",uScriptPath.c_str());
    
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            deInitClosure();
        }
        
        if(director->getScriptRunTimeError()==true){
            //we have to initialize the script again if there was a script-runtime error. But first we need to free all user input objects created such as lists and maps
            //IT SEEMS THAT SINCE I'M TRANSFERRING OWNERSHIP TO GRAVITY, THAT I SHOULDN'T HAVE TO DO THIS. LEAVING IT HERE JUST IN CASE I'M WRONG.
            //freeUserInputObjects();
            
            init();
        }
        
        // setup compiler
        compiler = gravity_compiler_create(&delegate);
        
        size_t size = 0;
        const char *source_code = file_read(uScriptPath.c_str(), &size);
        gravity_closure_t *closure = gravity_compiler_run(compiler, source_code, size, 0, false, true);
        
        if (!closure){
            
            // an error occurred while compiling source code and it has already been reported by the report_error callback
            
            
            director->setScriptCompiledSuccessfully(false);
            
            gravity_compiler_free(compiler);
            return false; // syntax/semantic error
        }
        
        director->setScriptCompiledSuccessfully(true);
        director->setScriptRunTimeError(false);
        
        gravity_vm_loadclosure(vm, closure);
        
        // transfer memory from compiler to VM
        gravity_compiler_transfer(compiler, vm);
        
        gravity_compiler_free(compiler);
        
        return true;
        
    }

    bool U4DScriptManager::init(){
        
        // setup delegate
        delegate = {
            .error_callback = reportError,
            .bridge_free = freeObjects,
            .loadfile_callback = loadFileCallback
        };
        
        
        // setup Gravity VM
        vm = gravity_vm_new(&delegate);
        
        // register my C++ classes inside Gravity VM
        registerClasses(vm);
        
        //set up strings used for userInput transaction
        userInputElementArray[inputElementType]=VALUE_FROM_CSTRING(vm, "inputElementType");
        userInputElementArray[inputElementAction]=VALUE_FROM_CSTRING(vm, "inputElementAction");
        userInputElementArray[joystickDirection]=VALUE_FROM_CSTRING(vm, "joystickDirection");
        
        userInputElementArray[inputPosition]=VALUE_FROM_CSTRING(vm, "inputPosition");
        userInputElementArray[previousMousePosition]=VALUE_FROM_CSTRING(vm, "previousMousePosition");
        userInputElementArray[mouseDeltaPosition]=VALUE_FROM_CSTRING(vm, "mouseDeltaPosition");
        
        userInputElementArray[joystickChangeDirection]=VALUE_FROM_CSTRING(vm, "joystickChangeDirection");
        userInputElementArray[mouseChangeDirection]=VALUE_FROM_CSTRING(vm, "mouseChangeDirection");
        userInputElementArray[arrowKeyDirection]=VALUE_FROM_CSTRING(vm, "arrowKeyDirection");
        userInputElementArray[elementUIName]=VALUE_FROM_CSTRING(vm, "elementUIName");
        userInputElementArray[dataValue]=VALUE_FROM_CSTRING(vm, "dataValue");
        
        
        joystickDirectionList=gravity_list_new(vm, 2);
        inputPositionList=gravity_list_new(vm, 2);
        previousMousePositionList=gravity_list_new(vm, 2);
        mouseDeltaPositionList=gravity_list_new(vm, 2);
        arrowKeyDirectionList=gravity_list_new(vm, 2);
        
        //create map- 11 is the number of elements in the CONTROLLERMESSAGE STRUCT
        controllerInputMessageMap=gravity_map_new(vm,11);
        
        /*IT SEEMS I DON'T HAVE TO DO THIS ANYMORE. LEAVING IT HERE IN CASE I'M WRONG
        //transfer ownership to gravity-
        
        // transfer newly allocated object to the VM
        
        gravity_vm_transfer(vm, (gravity_object_t*) joystickDirectionList);
        gravity_vm_transfer(vm, (gravity_object_t*) inputPositionList);
        gravity_vm_transfer(vm, (gravity_object_t*) previousMousePositionList);
        gravity_vm_transfer(vm, (gravity_object_t*) mouseDeltaPositionList);
        gravity_vm_transfer(vm, (gravity_object_t*) mouseDeltaPositionList);

        gravity_vm_transfer(vm, (gravity_object_t*) controllerInputMessageMap);
        */
        
        //if (loadScript(uScriptPath)) {
            
         
            return true;
        //}
        
        //return false;
        
    }

const char *U4DScriptManager::loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static) {
         (void) fileid, (void) xdata;
         if (is_static) *is_static = false;

         if (file_exists(path)) return file_read(path, size);

         // this unittest is able to resolve path only next to main test folder (not in nested folders)
         const char *newpath = file_buildpath(path, "/Users/haroldserrano/Desktop/UntoldEngineStudio/ScriptingSystem/ScriptingSystem");
         if (!newpath) return NULL;

         const char *buffer = file_read(newpath, size);
         mem_free(newpath);

         return buffer;

     }

    void U4DScriptManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        vector3nFree(vm,obj);
        //matrix3nFree(vm,obj);
    }

    void U4DScriptManager::registerClasses(gravity_vm *vm){
            
        gravity_class_t *scriptBridgeClass = gravity_class_new_pair(vm, "untold", NULL, 0, 0);
        gravity_class_t *scriptBridgeClassMeta = gravity_class_get_meta(scriptBridgeClass);

        gravity_class_bind(scriptBridgeClassMeta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(bridgeInstance));
        gravity_class_bind(scriptBridgeClass, "loadModel", NEW_CLOSURE_VALUE(loadModel));
        gravity_class_bind(scriptBridgeClass, "addChildModel", NEW_CLOSURE_VALUE(addChild));
        gravity_class_bind(scriptBridgeClass, "removeChildModel", NEW_CLOSURE_VALUE(removeChild));
        gravity_class_bind(scriptBridgeClass, "translateTo", NEW_CLOSURE_VALUE(translateTo));
        gravity_class_bind(scriptBridgeClass, "translateBy", NEW_CLOSURE_VALUE(translateBy));
        gravity_class_bind(scriptBridgeClass, "rotateTo", NEW_CLOSURE_VALUE(rotateTo));
        gravity_class_bind(scriptBridgeClass, "rotateBy", NEW_CLOSURE_VALUE(rotateBy));
        gravity_class_bind(scriptBridgeClass, "getAbsolutePosition", NEW_CLOSURE_VALUE(getAbsolutePosition));
        gravity_class_bind(scriptBridgeClass, "getAbsoluteOrientation", NEW_CLOSURE_VALUE(getAbsoluteOrientation));
        gravity_class_bind(scriptBridgeClass, "getViewInDirection", NEW_CLOSURE_VALUE(getViewInDirection));
        gravity_class_bind(scriptBridgeClass, "setViewInDirection", NEW_CLOSURE_VALUE(setViewInDirection));
        gravity_class_bind(scriptBridgeClass, "setEntityForwardVector", NEW_CLOSURE_VALUE(setEntityForwardVector));
        
        gravity_class_bind(scriptBridgeClass, "initPhysics", NEW_CLOSURE_VALUE(initPhysics));
        gravity_class_bind(scriptBridgeClass, "deinitPhysics", NEW_CLOSURE_VALUE(deinitPhysics));
        gravity_class_bind(scriptBridgeClass, "applyVelocity", NEW_CLOSURE_VALUE(applyVelocity));
        gravity_class_bind(scriptBridgeClass, "setGravity", NEW_CLOSURE_VALUE(setGravity));
        gravity_class_bind(scriptBridgeClass, "setCollisionFilterCategory", NEW_CLOSURE_VALUE(setCollisionFilterCategory));
        gravity_class_bind(scriptBridgeClass, "setCollisionFilterMask", NEW_CLOSURE_VALUE(setCollisionFilterMask));
        gravity_class_bind(scriptBridgeClass, "setCollidingTag", NEW_CLOSURE_VALUE(setCollidingTag));
        gravity_class_bind(scriptBridgeClass, "setIsCollisionSensor", NEW_CLOSURE_VALUE(setIsCollisionSensor));
        gravity_class_bind(scriptBridgeClass, "getModelHasCollided", NEW_CLOSURE_VALUE(getModelHasCollided));
        gravity_class_bind(scriptBridgeClass, "getCollisionListTags", NEW_CLOSURE_VALUE(getCollisionListTags));
        gravity_class_bind(scriptBridgeClass, "initMass", NEW_CLOSURE_VALUE(initMass));
        gravity_class_bind(scriptBridgeClass, "pauseCollisionBehavior", NEW_CLOSURE_VALUE(pauseCollisionBehavior));
        gravity_class_bind(scriptBridgeClass, "resumeCollisionBehavior", NEW_CLOSURE_VALUE(resumeCollisionBehavior));
        gravity_class_bind(scriptBridgeClass, "initAsPlatform", NEW_CLOSURE_VALUE(initAsPlatform));
        
        
        gravity_class_bind(scriptBridgeClass, "initAnimations", NEW_CLOSURE_VALUE(initAnimations));
        gravity_class_bind(scriptBridgeClass, "deinitAnimations", NEW_CLOSURE_VALUE(deinitAnimations));
        gravity_class_bind(scriptBridgeClass, "playAnimation", NEW_CLOSURE_VALUE(playAnimation));
        gravity_class_bind(scriptBridgeClass, "stopAnimation", NEW_CLOSURE_VALUE(stopAnimation));
        gravity_class_bind(scriptBridgeClass, "setEntityToArmatureBoneSpace", NEW_CLOSURE_VALUE(setEntityToArmatureBoneSpace));
        gravity_class_bind(scriptBridgeClass, "setEntityToAnimationBoneSpace", NEW_CLOSURE_VALUE(setEntityToAnimationBoneSpace));
        gravity_class_bind(scriptBridgeClass, "setPlayContinuousLoop", NEW_CLOSURE_VALUE(setPlayContinuousLoop));
        gravity_class_bind(scriptBridgeClass, "getAnimationIsPlaying", NEW_CLOSURE_VALUE(getAnimationIsPlaying));
        gravity_class_bind(scriptBridgeClass, "getCurrentKeyframe", NEW_CLOSURE_VALUE(getCurrentKeyframe));
        
        gravity_class_bind(scriptBridgeClass, "seek", NEW_CLOSURE_VALUE(seek));
        gravity_class_bind(scriptBridgeClass, "arrive", NEW_CLOSURE_VALUE(arrive));
        gravity_class_bind(scriptBridgeClass, "pursuit", NEW_CLOSURE_VALUE(pursuit));
        
        gravity_class_bind(scriptBridgeClass, "setCameraAsThirdPerson", NEW_CLOSURE_VALUE(setCameraAsThirdPerson));
        gravity_class_bind(scriptBridgeClass, "setCameraAsFirstPerson", NEW_CLOSURE_VALUE(setCameraAsFirstPerson));
        gravity_class_bind(scriptBridgeClass, "setCameraAsBasicFollow", NEW_CLOSURE_VALUE(setCameraAsBasicFollow));
        
        gravity_class_bind(scriptBridgeClass, "pauseScene", NEW_CLOSURE_VALUE(pauseScene));
        gravity_class_bind(scriptBridgeClass, "playScene", NEW_CLOSURE_VALUE(playScene));
        gravity_class_bind(scriptBridgeClass, "anchorMouse", NEW_CLOSURE_VALUE(anchorMouse));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "untold", VALUE_FROM_OBJECT(scriptBridgeClass));
        
        //create vector3n class
            
        gravity_class_t *vector3n_class = gravity_class_new_pair(vm, "U4DVector3n", NULL, 0, 0);
        gravity_class_t *vector3n_class_meta = gravity_class_get_meta(vector3n_class);
        
        gravity_class_bind(vector3n_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(vector3nNew));
        
        gravity_class_bind(vector3n_class, "x", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(xGet), NEW_FUNCTION(xSet))));
        gravity_class_bind(vector3n_class, "y", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(yGet), NEW_FUNCTION(ySet))));
        gravity_class_bind(vector3n_class, "z", VALUE_FROM_OBJECT(computed_property_create(NULL, NEW_FUNCTION(zGet), NEW_FUNCTION(zSet))));
        
        gravity_class_bind(vector3n_class, "magnitude", NEW_CLOSURE_VALUE(vector3nMagnitude));
        gravity_class_bind(vector3n_class, "normalize", NEW_CLOSURE_VALUE(vector3nNormalize));
        gravity_class_bind(vector3n_class, "dot", NEW_CLOSURE_VALUE(vector3nDot));
        gravity_class_bind(vector3n_class, "cross", NEW_CLOSURE_VALUE(vector3nCross));
        gravity_class_bind(vector3n_class, "angle", NEW_CLOSURE_VALUE(vector3nAngle));
        
        gravity_class_bind(vector3n_class, "show", NEW_CLOSURE_VALUE(vector3nShow));
        
        gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_ADD_NAME, NEW_CLOSURE_VALUE(vector3nAdd));
        gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_SUB_NAME, NEW_CLOSURE_VALUE(vector3nSub));
        gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_MUL_NAME, NEW_CLOSURE_VALUE(vector3nMul));
        gravity_class_bind(vector3n_class, GRAVITY_OPERATOR_DIV_NAME, NEW_CLOSURE_VALUE(vector3nDiv));
        
        // register vector3n class inside VM
        gravity_vm_setvalue(vm, "U4DVector3n", VALUE_FROM_OBJECT(vector3n_class));
        
        //create U4DMatrix3n class
           
       gravity_class_t *matrix3n_class = gravity_class_new_pair(vm, "U4DMatrix3n", NULL, 0, 0);
       gravity_class_t *matrix3n_class_meta = gravity_class_get_meta(matrix3n_class);
       
       gravity_class_bind(matrix3n_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(matrix3nNew));
       gravity_class_bind(matrix3n_class, "show", NEW_CLOSURE_VALUE(matrix3nShow));
       
       gravity_class_bind(matrix3n_class, GRAVITY_OPERATOR_MUL_NAME, NEW_CLOSURE_VALUE(matrix3nTransformVector));
       
       // register U4DMatrix3n class inside VM
       gravity_vm_setvalue(vm, "U4DMatrix3n", VALUE_FROM_OBJECT(matrix3n_class));
        
        //logger
        gravity_class_t *logger_class = gravity_class_new_pair(vm, "U4DLogger", NULL, 0, 0);
        gravity_class_t *logger_class_meta = gravity_class_get_meta(logger_class);
        
        gravity_class_bind(logger_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(loggerNew));
        gravity_class_bind(logger_class, "log", NEW_CLOSURE_VALUE(loggerLog));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "U4DLogger", VALUE_FROM_OBJECT(logger_class));
        
        //camera
        gravity_class_t *camera_class = gravity_class_new_pair(vm, "U4DCamera", NULL, 0, 0);
            gravity_class_t *camera_class_meta = gravity_class_get_meta(camera_class);
            
        gravity_class_bind(camera_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(cameraNew));
        
        gravity_class_bind(camera_class, "translateTo", NEW_CLOSURE_VALUE(cameraTranslateTo));
        gravity_class_bind(camera_class, "translateBy", NEW_CLOSURE_VALUE(cameraTranslateBy));
        gravity_class_bind(camera_class, "rotateTo", NEW_CLOSURE_VALUE(cameraRotateTo));
        gravity_class_bind(camera_class, "rotateBy", NEW_CLOSURE_VALUE(cameraRotateBy));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "U4DCamera", VALUE_FROM_OBJECT(camera_class));
        
    }

    void U4DScriptManager::reportError (gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata) {
            #pragma unused(vm, xdata)
            
        U4DLogger *logger=U4DLogger::sharedInstance();
        
            const char *type = "N/A";
            switch (error_type) {
                case GRAVITY_ERROR_NONE: type = "NONE"; break;
                case GRAVITY_ERROR_SYNTAX: type = "SYNTAX"; break;
                case GRAVITY_ERROR_SEMANTIC: type = "SEMANTIC"; break;
                case GRAVITY_ERROR_RUNTIME: type = "RUNTIME"; break;
                case GRAVITY_WARNING: type = "WARNING"; break;
                case GRAVITY_ERROR_IO: type = "I/O"; break;
            }
            
            if (error_type == GRAVITY_ERROR_RUNTIME) logger->log("RUNTIME ERROR: ");
            else logger->log("%s ERROR on %d (%d,%d): ", type, error_desc.fileid, error_desc.lineno, error_desc.colno);
            logger->log("%s\n", message);
        
        U4DDirector *director=U4DDirector::sharedInstance();
        director->setScriptRunTimeError(true);
    }

    void U4DScriptManager::removeItemsInList(gravity_list_t *l){
        
        size_t count = marray_size(l->array);

        //pop all items in array
        for(int i=0;i<count;i++){
            marray_pop(l->array);
        }
        
    }

    void U4DScriptManager::freeUserInputObjects(){
        
        //free up all strings that were mem allocated
        for(auto n:userInputElementArray){
            gravity_string_free(vm, VALUE_AS_STRING(n));
        }
        
        //free up all lists that were mem allocated
        
        gravity_list_free(vm,joystickDirectionList);
        gravity_list_free(vm,inputPositionList);
        gravity_list_free(vm,previousMousePositionList);
        gravity_list_free(vm,mouseDeltaPositionList);
        gravity_list_free(vm,arrowKeyDirectionList);
        
        //free up map that was mem allocated
        gravity_map_free(vm, controllerInputMessageMap);
        
    }

    void U4DScriptManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
