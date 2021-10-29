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

    bool U4DScriptManager::loadModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        gravity_value_t assetName=GET_VALUE(1);
        
        if (VALUE_ISA_STRING(assetName)) {
            
            gravity_string_t *v=(gravity_string_t *)assetName.p;
            std::string name(v->s);
            
            std::string entityName=scriptBridge->loadModel(name);
            
            gravity_value_t gravityEntityName = VALUE_FROM_CSTRING(NULL, entityName.c_str());
            gravity_string_t *n=(gravity_string_t *)gravityEntityName.p;
            
            RETURN_VALUE(VALUE_FROM_STRING(vm, n->s, n->len),rindex);
            
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

    bool U4DScriptManager::log(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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
        }else if(VALUE_ISA_LIST(value)){
            
            gravity_list_t *list = VALUE_AS_LIST(value);
            
            //size of array
            int32_t count = (int32_t)marray_size(list->array);
            if(count==3){
                
                gravity_float_t x=(marray_get(list->array,0)).f;
                gravity_float_t y=(marray_get(list->array,1)).f;
                gravity_float_t z=(marray_get(list->array,2)).f;
                
                logger->log("%f,%f,%f",x,y,z);
                
            }
        }

        RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        
    }

    bool U4DScriptManager::translateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        // get self object which is the instance created in create function
        //gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //Here it would be nice to go through the variable argument list. However, I don't know if Gravity supports it yet.
             //So for now, I'll just go through each argument and check the type
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();

        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n position(x,y,z);
                    
                    scriptBridge->translateTo(name, position);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
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
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n position(x,y,z);
                    
                    scriptBridge->translateBy(name, position);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                }
                
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
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n orientation(x,y,z);
                    
                    scriptBridge->rotateTo(name, orientation);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
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
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n orientation(x,y,z);
                    
                    scriptBridge->rotateBy(name, orientation);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }else if (nargs==4) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t angle=GET_VALUE(2);
            gravity_value_t axis=GET_VALUE(3);
            
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_FLOAT(angle) && VALUE_ISA_LIST(axis)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_float_t angleValue=angle.f;
                
                gravity_list_t *list = VALUE_AS_LIST(axis);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n axisVector(x,y,z);
                    
                    scriptBridge->rotateBy(name,angleValue, axisVector);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
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
                
                //create a new list
                gravity_list_t *l=gravity_list_new(NULL, 3);
                
                //load the vector components into the list
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.x));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.y));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absolutePosition.z));
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
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
                gravity_list_t *l=gravity_list_new(NULL, 3);
                
                //load the vector components into the list
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.x));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.y));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(absoluteOrientation.z));
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
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
                
                //create a new list
                gravity_list_t *l=gravity_list_new(NULL, 3);
                
                //load the vector components into the list
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.x));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.y));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(viewDirection.z));
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t targetPos=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(targetPos)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                //unpack the list into a vector
                gravity_list_t *list = VALUE_AS_LIST(targetPos);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n direction(x,y,z);
                    
                    //move in direction
                    scriptBridge->setViewInDirection(name, direction);
                    
                    
                    RETURN_VALUE(VALUE_FROM_TRUE, rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of vector must be size 3");
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }

    bool U4DScriptManager::setEntityForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t viewDirection=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(viewDirection)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                //unpack the list into a vector
                gravity_list_t *list = VALUE_AS_LIST(viewDirection);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n direction(x,y,z);
                    
                    //move in direction
                    scriptBridge->setEntityForwardVector(name, direction);
                    
                    
                    RETURN_VALUE(VALUE_FROM_TRUE, rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of vector must be size 3");
                }
                
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
            gravity_value_t listValue=GET_VALUE(2);
            gravity_value_t dtValue=GET_VALUE(3);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue) && VALUE_ISA_FLOAT(dtValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_float_t dt=dtValue.f;
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n velocity(x,y,z);
                    
                    scriptBridge->applyVelocity(name, velocity,dt);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of list must be size 3");
                }
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }
    
    bool U4DScriptManager::setGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n gravity(x,y,z);
                    
                    scriptBridge->setGravity(name, gravity);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of vector must be size 3");
                }
                
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
            gravity_value_t targetPos=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(targetPos)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                //unpack the list into a vector
                gravity_list_t *list = VALUE_AS_LIST(targetPos);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n targetPosition(x,y,z);
                    
                    //compute the final velocity
                    U4DVector3n finalVelocity=scriptBridge->seek(name, targetPosition);
                    
                    //convert the vector to a list
                    
                    //create a new list
                    gravity_list_t *l=gravity_list_new(NULL, 3);
                    
                    //load the vector components into the list
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.x));
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.y));
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.z));
                    
                    // transfer newly allocated object to the VM
                    gravity_vm_transfer(vm, (gravity_object_t*) l);
                    
                    //return a list object
                    RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of vector must be size 3");
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
        
    }

    bool U4DScriptManager::arrive(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if(nargs==3){
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t targetPos=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(targetPos)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                //unpack the list into a vector
                gravity_list_t *list = VALUE_AS_LIST(targetPos);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n targetPosition(x,y,z);
                    
                    //compute the final velocity
                    U4DVector3n finalVelocity=scriptBridge->arrive(name, targetPosition);
                    
                    //convert the vector to a list
                    
                    //create a new list
                    gravity_list_t *l=gravity_list_new(NULL, 3);
                    
                    //load the vector components into the list
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.x));
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.y));
                    marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.z));
                    
                    // transfer newly allocated object to the VM
                    gravity_vm_transfer(vm, (gravity_object_t*) l);
                    
                    //return a list object
                    RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of vector must be size 3");
                }
                
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
                
                //convert the vector to a list
                
                //create a new list
                gravity_list_t *l=gravity_list_new(NULL, 3);
                
                //load the vector components into the list
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.x));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.y));
                marray_push(gravity_value_t, l->array, VALUE_FROM_FLOAT(finalVelocity.z));
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                //return a list object
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
                
            }
            
        }else{
            U4DLogger *logger = U4DLogger::sharedInstance();
            logger->log("The names for the pursuer and evader must be in string format");
        }
        
        RETURN_VALUE(VALUE_FROM_FALSE, rindex);
    }
 
    bool U4DScriptManager::setCameraAsThirdPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n uOffset(x,y,z);
                    
                    scriptBridge->setCameraAsThirdPerson(name, uOffset);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of list must be size 3");
                }
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::setCameraAsFirstPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n uOffset(x,y,z);
                    
                    scriptBridge->setCameraAsFirstPerson(name, uOffset);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of list must be size 3");
                }
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::setCameraAsBasicFollow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DScriptBridge *scriptBridge = U4DScriptBridge::sharedInstance();
        
        if (nargs==3) {
            
            gravity_value_t entity=GET_VALUE(1);
            gravity_value_t listValue=GET_VALUE(2);
            
            if (VALUE_ISA_STRING(entity) && VALUE_ISA_LIST(listValue)) {
                
                gravity_string_t *v=(gravity_string_t *)entity.p;
                std::string name(v->s);
                
                
                gravity_list_t *list = VALUE_AS_LIST(listValue);
                
                //size of array
                int32_t count = (int32_t)marray_size(list->array);
                
                if(count==3){
                    
                    gravity_float_t x=(marray_get(list->array,0)).f;
                    gravity_float_t y=(marray_get(list->array,1)).f;
                    gravity_float_t z=(marray_get(list->array,2)).f;
                    
                    U4DVector3n uOffset(x,y,z);
                    
                    scriptBridge->setCameraAsBasicFollow(name, uOffset);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    U4DLogger *logger = U4DLogger::sharedInstance();
                    logger->log("Size of list must be size 3");
                }
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
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
            freeUserInputObjects();
            
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
        
        
        //transfer ownership to gravity
        
        // transfer newly allocated object to the VM
        /*
        for(auto n:userInputElementArray){
            gravity_vm_transfer(vm, (gravity_object_t*) VALUE_AS_STRING(n));
        }
        
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
         const char *newpath = file_buildpath(path, "/Users/haroldserrano/Downloads/UntoldEngineScripts/");
         if (!newpath) return NULL;

         const char *buffer = file_read(newpath, size);
         mem_free(newpath);

         return buffer;

     }

    void U4DScriptManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        
        
    }

    void U4DScriptManager::registerClasses(gravity_vm *vm){
            
        gravity_class_t *scriptBridgeClass = gravity_class_new_pair(vm, "untold", NULL, 0, 0);
        gravity_class_t *scriptBridgeClassMeta = gravity_class_get_meta(scriptBridgeClass);

        gravity_class_bind(scriptBridgeClassMeta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(bridgeInstance));
        gravity_class_bind(scriptBridgeClass, "loadModel", NEW_CLOSURE_VALUE(loadModel));
        gravity_class_bind(scriptBridgeClass, "addChild", NEW_CLOSURE_VALUE(addChild));
        gravity_class_bind(scriptBridgeClass, "removeChild", NEW_CLOSURE_VALUE(removeChild));
        gravity_class_bind(scriptBridgeClass, "log", NEW_CLOSURE_VALUE(log));
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
        
        gravity_class_bind(scriptBridgeClass, "initAnimations", NEW_CLOSURE_VALUE(initAnimations));
        gravity_class_bind(scriptBridgeClass, "deinitAnimations", NEW_CLOSURE_VALUE(deinitAnimations));
        gravity_class_bind(scriptBridgeClass, "playAnimation", NEW_CLOSURE_VALUE(playAnimation));
        gravity_class_bind(scriptBridgeClass, "stopAnimation", NEW_CLOSURE_VALUE(stopAnimation));
        gravity_class_bind(scriptBridgeClass, "setEntityToArmatureBoneSpace", NEW_CLOSURE_VALUE(setEntityToArmatureBoneSpace));
        gravity_class_bind(scriptBridgeClass, "setEntityToAnimationBoneSpace", NEW_CLOSURE_VALUE(setEntityToAnimationBoneSpace));
        
        gravity_class_bind(scriptBridgeClass, "seek", NEW_CLOSURE_VALUE(seek));
        gravity_class_bind(scriptBridgeClass, "arrive", NEW_CLOSURE_VALUE(arrive));
        gravity_class_bind(scriptBridgeClass, "pursuit", NEW_CLOSURE_VALUE(pursuit));
        
        gravity_class_bind(scriptBridgeClass, "setCameraAsThirdPerson", NEW_CLOSURE_VALUE(setCameraAsThirdPerson));
        gravity_class_bind(scriptBridgeClass, "setCameraAsFirstPerson", NEW_CLOSURE_VALUE(setCameraAsFirstPerson));
        gravity_class_bind(scriptBridgeClass, "setCameraAsBasicFollow", NEW_CLOSURE_VALUE(setCameraAsBasicFollow));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "untold", VALUE_FROM_OBJECT(scriptBridgeClass));
        
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
