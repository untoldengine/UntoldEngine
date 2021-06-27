//
//  U4DScriptBindModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBindModel.h"
#include "U4DScriptBindManager.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DScriptInstanceManager.h"
#include "U4DLogger.h"

namespace U4DEngine {

    

    U4DScriptBindModel* U4DScriptBindModel::instance=0;

    U4DScriptBindModel* U4DScriptBindModel::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DScriptBindModel();
        }

        return instance;
    }

    U4DScriptBindModel::U4DScriptBindModel(){
         
            
        }

    U4DScriptBindModel::~U4DScriptBindModel(){
            
        }


    bool U4DScriptBindModel::modelCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the model create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(vm, c);
        
        U4DModel *model = new U4DModel();
        
//        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
//        scriptInstanceManager->loadModelScriptInstance(model, instance);
        
        
        // set cpp instance and xdata of the gravity instance
        gravity_instance_setxdata(instance, model);
        
        // return instance
        RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
    }

    bool U4DScriptBindModel::modelLoad(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex) {
        
        // get self object which is the instance created in player_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_value_t nameValue=GET_VALUE(1);
        gravity_value_t pipelineValue=GET_VALUE(2);
        
//        gravity_string_t *name=(gravity_string_t *)GET_VALUE(1).p;
//
//        gravity_string_t *pipelineName=(gravity_string_t *)GET_VALUE(2).p;
        
        // get xdata
        U4DModel *model = (U4DModel *)instance->xdata;
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        
        U4DScene *scene=sceneManager->getCurrentScene();
        
        bool d=false;
        
        if (scene!=nullptr && model!=nullptr && VALUE_ISA_STRING(nameValue)) {
            
            U4DWorld *world=scene->getGameWorld();
            gravity_string_t *name=(gravity_string_t *)nameValue.p;
            
            if (model->loadModel(name->s)) {
                
                if (VALUE_ISA_STRING(pipelineValue) && nargs==3) {

                    gravity_string_t *pipelineName=(gravity_string_t *)pipelineValue.p;

                    model->setPipeline(pipelineName->s);

                }
                model->loadRenderingInformation();
                
                world->addChild(model);
                
                U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
                scriptInstanceManager->loadModelScriptInstance(model, instance);
                
                
                d=true;
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
    }

bool U4DScriptBindModel::modelAddChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

    gravity_value_t childValue=GET_VALUE(1);
    
    bool d=false;
    
    if (VALUE_ISA_INSTANCE(childValue)) {
        
        gravity_instance_t *childInstance=(gravity_instance_t *)childValue.p;
        
        U4DModel *model = (U4DModel *)instance->xdata;
        U4DModel *child=(U4DModel *)childInstance->xdata;
    
    
        if (model!=nullptr && child!=nullptr) {
            
            U4DEntity *parent=child->getParent();
            parent->removeChild(child);
            model->addChild(child);
            
            d=true;
        }
    }else{
    
            U4DLogger *logger=U4DLogger::sharedInstance();
            logger->log("Unable to add child. Please check that both instances are of U4DModel type");
        }
    
    RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
    
}

bool U4DScriptBindModel::modelGetAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
    
    // get self object which is the instance created in player_create function
    gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
    
    // get xdata
    U4DModel *model = (U4DModel *)instance->xdata;
    
    U4DVector3n v=model->getAbsolutePosition();
    
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

    bool U4DScriptBindModel::modelTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==4) {
        
            if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
                
                gravity_float_t v1 = GET_VALUE(1).f;
                gravity_float_t v2 = GET_VALUE(2).f;
                gravity_float_t v3 = GET_VALUE(3).f;
                
                U4DModel *model = (U4DModel *)instance->xdata;
                
                model->translateTo(v1, v2, v3);
                
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

    bool U4DScriptBindModel::modelTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==4) {
        
            if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
                
                gravity_float_t v1 = GET_VALUE(1).f;
                gravity_float_t v2 = GET_VALUE(2).f;
                gravity_float_t v3 = GET_VALUE(3).f;
                
                U4DModel *model = (U4DModel *)instance->xdata;
                
                model->translateBy(v1, v2, v3);
                
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

    bool U4DScriptBindModel::modelRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if(nargs==2){
            
            gravity_value_t quaternionValue=GET_VALUE(1);
            
            if (VALUE_ISA_INSTANCE(quaternionValue)) {
                
                gravity_instance_t *quaterionInstance=(gravity_instance_t*)quaternionValue.p;
                
                U4DQuaternion *q=(U4DQuaternion*)quaterionInstance->xdata;
                
                U4DModel *model = (U4DModel *)instance->xdata;
                
                model->rotateTo(*q);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
            }
            
        }else if(nargs==4) {
        
            if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
                
                gravity_float_t v1 = GET_VALUE(1).f;
                gravity_float_t v2 = GET_VALUE(2).f;
                gravity_float_t v3 = GET_VALUE(3).f;
                
                U4DModel *model = (U4DModel *)instance->xdata;
                
                model->rotateTo(v1, v2, v3);
                
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

    bool U4DScriptBindModel::modelRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==4) {
        
            if (VALUE_ISA_FLOAT(GET_VALUE(1)) &&  VALUE_ISA_FLOAT(GET_VALUE(2)) && VALUE_ISA_FLOAT(GET_VALUE(3))) {
                
                gravity_float_t v1 = GET_VALUE(1).f;
                gravity_float_t v2 = GET_VALUE(2).f;
                gravity_float_t v3 = GET_VALUE(3).f;
                
                U4DModel *model = (U4DModel *)instance->xdata;
                
                model->rotateBy(v1, v2, v3);
                
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

    bool U4DScriptBindModel::modelSetLocalSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        //get the instance for matrix
        gravity_value_t localSpaceMatrixValue=GET_VALUE(1);
        
        if (VALUE_ISA_INSTANCE(localSpaceMatrixValue)) {
            
            gravity_instance_t *localSpaceMatrix=(gravity_instance_t*)localSpaceMatrixValue.p;
            
            U4DMatrix4n *m=(U4DMatrix4n*)localSpaceMatrix->xdata;
            
            U4DModel *model = (U4DModel *)instance->xdata;
            
            model->setLocalSpace(*m);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptBindModel::modelSetForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        //get the instance for matrix
        gravity_value_t forwardVectorValue=GET_VALUE(1);
        
        if (VALUE_ISA_INSTANCE(forwardVectorValue)) {
            
            gravity_instance_t *forwardVectorInstance=(gravity_instance_t*)forwardVectorValue.p;
            
            U4DVector3n *forwardVector=(U4DVector3n*)forwardVectorInstance->xdata;
            
            U4DModel *model = (U4DModel *)instance->xdata;
            
            model->setEntityForwardVector(*forwardVector);
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptBindModel::modelGetForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DModel *model = (U4DModel *)instance->xdata;
        
        U4DVector3n v=model->getEntityForwardVector();
        
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

    bool U4DScriptBindModel::modelGetViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DModel *model = (U4DModel *)instance->xdata;
        
        U4DVector3n v=model->getViewInDirection();
        
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

    bool U4DScriptBindModel::modelGetAbsMatrixOrientation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DModel *model = (U4DModel *)instance->xdata;
        
        U4DMatrix3n m=model->getAbsoluteMatrixOrientation();
        
        //float m0,float m3,float m6,float m1,float m4,float m7,float m2,float m5,float m8
        // create a new vector type
        U4DMatrix3n *r = new U4DMatrix3n(m.matrixData[0],m.matrixData[3],m.matrixData[6],
                                         m.matrixData[1],m.matrixData[4],m.matrixData[7],
                                         m.matrixData[2],m.matrixData[5],m.matrixData[8]);


        // lookup class "U4DMatrix3n" already registered inside the VM
        // a faster way would be to save a global variable of type gravity_class_t *
        // set with the result of gravity_class_new_pair (like I did in gravity_core.c -> gravity_core_init)

        // error not handled here but it should be checked
        gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DMatrix3n", strlen("U4DMatrix3n")));

        // create a Player instance
        gravity_instance_t *result = gravity_instance_new(vm, c);

        //setting the vector data to result
        gravity_instance_setxdata(result, r);

        RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
        
    }

    bool U4DScriptBindModel::modelLoadAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        bool d=false;
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_instance_t *animationInstance = (gravity_instance_t *)GET_VALUE(1).p;
        gravity_value_t animationName=GET_VALUE(2);
        
        if(instance!=nullptr && animationInstance!=nullptr && VALUE_ISA_STRING(animationName)){
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
            
            U4DAnimation *animation=(U4DAnimation *)animationInstance->xdata;
            
            gravity_string_t *v=(gravity_string_t *)animationName.p;
            
            model->loadAnimationToModel(animation, v->s);
            
            d=true;
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptBindModel::modelGetBoneRestPose(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
       
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //get the string-name of bone
        gravity_value_t boneNameValue=GET_VALUE(1);
        
        //get the instance for matrix
        gravity_value_t restPoseMatrixValue=GET_VALUE(2);
        
        if (VALUE_ISA_STRING(boneNameValue) && VALUE_ISA_INSTANCE(restPoseMatrixValue)) {
            gravity_string_t *boneName=(gravity_string_t *)boneNameValue.p;
            gravity_instance_t *restPoseMatrix=(gravity_instance_t*)restPoseMatrixValue.p;
            
            U4DMatrix4n *m=(U4DMatrix4n*)restPoseMatrix->xdata;
            
            U4DModel *model = (U4DModel *)instance->xdata;
            
            if(model->getBoneRestPose(boneName->s, *m)){
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptBindModel::modelGetBoneAnimationPose(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        //get the string-name of bone
        gravity_value_t boneNameValue=GET_VALUE(1);
        
        //get animation instance
        gravity_value_t animationValue=GET_VALUE(2);
        
        //get the instance for matrix
        gravity_value_t poseMatrixValue=GET_VALUE(3);
        
        if (VALUE_ISA_STRING(boneNameValue) && VALUE_ISA_INSTANCE(animationValue) && VALUE_ISA_INSTANCE(poseMatrixValue)) {
            
            gravity_string_t *boneName=(gravity_string_t *)boneNameValue.p;
            gravity_instance_t *animationInstance=(gravity_instance_t*)animationValue.p;
            gravity_instance_t *poseMatrix=(gravity_instance_t*)poseMatrixValue.p;
            
            U4DMatrix4n *m=(U4DMatrix4n*)poseMatrix->xdata;
            U4DAnimation *animation=(U4DAnimation*)animationInstance->xdata;
            U4DModel *model = (U4DModel *)instance->xdata;
            
            if(model->getBoneAnimationPose(boneName->s, animation, *m)){
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptBindModel::modelSetPipeline(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in model_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        gravity_string_t *name=(gravity_string_t *)GET_VALUE(1).p;
        
        // get xdata
        U4DModel *model = (U4DModel *)instance->xdata;
        
        if (model!=nullptr) {
            
            model->setPipeline(name->s);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        
    }

    void U4DScriptBindModel::modelFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DModel *r = (U4DModel *)instance->xdata;
        
        // explicitly free memory
        delete r;
    }

    void U4DScriptBindModel::registerModelClasses(gravity_vm *vm){
        
        gravity_class_t *model_class = gravity_class_new_pair(vm, "U4DModel", NULL, 0, 0);
        gravity_class_t *model_class_meta = gravity_class_get_meta(model_class);
        
        gravity_class_bind(model_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(modelCreate));
        gravity_class_bind(model_class, "loadModel", NEW_CLOSURE_VALUE(modelLoad));
        gravity_class_bind(model_class, "addChild", NEW_CLOSURE_VALUE(modelAddChild));
        
        gravity_class_bind(model_class,"getAbsolutePosition",NEW_CLOSURE_VALUE(modelGetAbsolutePosition));
        gravity_class_bind(model_class, "translateTo", NEW_CLOSURE_VALUE(modelTranslateTo));
        gravity_class_bind(model_class, "translateBy", NEW_CLOSURE_VALUE(modelTranslateBy));
        gravity_class_bind(model_class, "rotateTo", NEW_CLOSURE_VALUE(modelRotateTo));
        gravity_class_bind(model_class, "rotateBy", NEW_CLOSURE_VALUE(modelRotateBy));
        gravity_class_bind(model_class, "setLocalSpace", NEW_CLOSURE_VALUE(modelSetLocalSpace));
        
        gravity_class_bind(model_class, "setEntityForwardVector", NEW_CLOSURE_VALUE(modelSetForwardVector));
        gravity_class_bind(model_class, "getEntityForwardVector", NEW_CLOSURE_VALUE(modelGetForwardVector));
        gravity_class_bind(model_class, "getViewInDirection", NEW_CLOSURE_VALUE(modelGetViewInDirection));
        gravity_class_bind(model_class, "getAbsoluteMatrixOrientation", NEW_CLOSURE_VALUE(modelGetAbsMatrixOrientation));
        
        
        gravity_class_bind(model_class, "getBoneRestPose", NEW_CLOSURE_VALUE(modelGetBoneRestPose));
        gravity_class_bind(model_class, "getBoneAnimationPose", NEW_CLOSURE_VALUE(modelGetBoneAnimationPose));
        
        gravity_class_bind(model_class, "setPipeline", NEW_CLOSURE_VALUE(modelSetPipeline));
        
        gravity_class_bind(model_class, "loadAnimationToModel", NEW_CLOSURE_VALUE(modelLoadAnimation));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DModel", VALUE_FROM_OBJECT(model_class));
    }

//    void initGravityFunction(){
//
//        gravity_value_t init_function = gravity_vm_getvalue(vm, "init", (uint32_t)strlen("init"));
//        if (!VALUE_ISA_CLOSURE(init_function)) {
//            printf("Unable to find init function into Gravity VM.\n");
//
//        }else{
//
//            // convert function to closure
//            gravity_closure_t *init_closure = VALUE_AS_CLOSURE(init_function);
//
//            // execute init closure
//            if (gravity_vm_runclosure (vm, init_closure, VALUE_FROM_NULL, 0, 0)) {
//
//            }
//        }
//
//    }

    void U4DScriptBindModel::update(int uScriptID, double dt){

        U4DScriptBindManager *bindManager=U4DScriptBindManager::sharedInstance();

        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        gravity_instance_t *model_instance=scriptInstanceManager->getModelScriptInstance(uScriptID);
        
        gravity_value_t key = VALUE_FROM_STRING(bindManager->vm, "update", (uint32_t)strlen("update"));

        gravity_closure_t *update_closure = (gravity_closure_t *)gravity_class_lookup_closure(gravity_value_getclass(VALUE_FROM_OBJECT(model_instance)), key);


        if (update_closure==nullptr) {

//            U4DLogger *logger=U4DLogger::sharedInstance();
//            logger->log("Unable to find update method into Gravity VM");

        }else{
            gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
            gravity_value_t params[] = {p1};

            // execute closure
            if (gravity_vm_runclosure (bindManager->vm, update_closure, VALUE_FROM_OBJECT(model_instance), params, 1)) {

            }
        }

    }

    

}
