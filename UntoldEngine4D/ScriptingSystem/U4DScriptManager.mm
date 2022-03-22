//
//  U4DScriptManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptManager.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DCamera.h"
#include "U4DGameConfigs.h"
#include "U4DSceneManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"
#include "U4DSceneStateManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DSteering.h"
#include "U4DSeek.h"
#include "U4DArrive.h"
#include "U4DPursuit.h"
#include "U4DScriptInstanceManager.h"
#include "U4DCameraInterface.h"
#include "U4DCameraFirstPerson.h"
#include "U4DCameraThirdPerson.h"
#include "U4DCameraBasicFollow.h"

#include "U4DTeam.h"
#include "U4DPlayer.h"

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

    void U4DScriptManager::updateClosure(double dt){

         U4DDirector *director=U4DDirector::sharedInstance();

         if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false){

             gravity_value_t update_function = gravity_vm_getvalue(vm, "update", (uint32_t)strlen("update"));
             if (!VALUE_ISA_CLOSURE(update_function)) {
                 //printf("Unable to find update function into Gravity VM.\n");

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

    void U4DScriptManager::update(int uScriptID, double dt){

        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        gravity_instance_t *model_instance=scriptInstanceManager->getModelScriptInstance(uScriptID);
        
        gravity_value_t key = VALUE_FROM_STRING(vm, "update", (uint32_t)strlen("update"));

        gravity_closure_t *update_closure = (gravity_closure_t *)gravity_class_lookup_closure(gravity_value_getclass(VALUE_FROM_OBJECT(model_instance)), key);


        if (update_closure==nullptr) {

//            U4DLogger *logger=U4DLogger::sharedInstance();
//            logger->log("Unable to find update method into Gravity VM");

        }else{
            gravity_value_t p1 = VALUE_FROM_FLOAT(dt);
            gravity_value_t params[] = {p1};

            // execute closure
            if (gravity_vm_runclosure (vm, update_closure, VALUE_FROM_OBJECT(model_instance), params, 1)) {

            }
        }

    }

    void U4DScriptManager::loadGameConfigs(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if (director->getScriptCompiledSuccessfully()==true && director->getScriptRunTimeError()==false) {
            
            gravity_value_t gameConfigs_function = gravity_vm_getvalue(vm, "gameConfigs", (uint32_t)strlen("gameConfigs"));
            if (!VALUE_ISA_CLOSURE(gameConfigs_function)) {
                printf("Unable to find gameConfigs function into Gravity VM.\n");
                
            }else{
                
                // convert function to closure
                gravity_closure_t *gameConfigs_closure = VALUE_AS_CLOSURE(gameConfigs_function);

                // execute init closure
                if (gravity_vm_runclosure (vm, gameConfigs_closure, VALUE_FROM_NULL, 0, 0)) {
                    
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

    bool U4DScriptManager::worldCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        // self parameter is the logger_class create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        // set cpp instance and xdata of the gravity instance
        gravity_instance_setxdata(instance, world);
        
        // return instance
        RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        
    }
    

    bool U4DScriptManager::loadModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        U4DModel *model=nullptr;
        
        if(nargs==2){
            
            gravity_value_t assetName=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(assetName)) {
                
                gravity_string_t *v=(gravity_string_t *)assetName.p;
                std::string name(v->s);
                
                //create a new model
                model=new U4DModel();
                
                if (model->loadModel(name.c_str())) {
                    
                    model->loadRenderingInformation();
                    
                    world->addChild(model);
                 
                }
                
            }
            
        }else if(nargs==3){
            gravity_value_t assetName=GET_VALUE(1);
            gravity_instance_t *positionValue = (gravity_instance_t *)GET_VALUE(2).p;

            if (VALUE_ISA_STRING(assetName)) {

            gravity_string_t *v=(gravity_string_t *)assetName.p;
            std::string name(v->s);

            U4DVector3n *position = (U4DVector3n *)positionValue->xdata;

                //create a new model
                model=new U4DModel();
                
                if (model->loadModel(name.c_str())) {
                    
                    model->loadRenderingInformation();
                    
                    world->addChild(model);
                    model->translateTo(*position);
                }
                
            }
            
        }
        
        //else if(nargs==3){
//
//            gravity_value_t assetName=GET_VALUE(1);
//            gravity_value_t pipelineName=GET_VALUE(2);
//
//            if (VALUE_ISA_STRING(assetName) && VALUE_ISA_STRING(pipelineName)) {
//
//                gravity_string_t *v=(gravity_string_t *)assetName.p;
//                std::string name(v->s);
//
//                gravity_string_t *pipe=(gravity_string_t *)pipelineName.p;
//                std::string pipeline(pipe->s);
//
//                //create a new model
//                model=new U4DModel();
//
//                if (model->loadModel(name.c_str())) {
//
//                    model->setPipeline(pipeline.c_str());
//
//                    model->loadRenderingInformation();
//
//                    world->addChild(model);
//
//                }
//
//            }
//        }
        
        if(model!=nullptr){
            std::string entityName=model->getName();
            
            gravity_value_t gravityEntityName = VALUE_FROM_CSTRING(NULL, entityName.c_str());
            gravity_string_t *n=(gravity_string_t *)gravityEntityName.p;
            
            RETURN_VALUE(VALUE_FROM_STRING(vm, n->s, n->len),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::removeModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        if(nargs==2){
            
            gravity_value_t modelName=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(modelName)) {
                
                gravity_string_t *v=(gravity_string_t *)modelName.p;
                std::string name(v->s);
                
                U4DEntity *model=world->searchChild(name);
                
                if(model!=nullptr){
                    
                    U4DEntity *parent=model->getParent();
                    parent->removeChild(model);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                }
     
            }
                        
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::anchorMouse(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==2) {
            
            gravity_value_t value=GET_VALUE(1);
            
            if (VALUE_ISA_BOOL(value)) {
                
                bool shouldAnchor=VALUE_AS_BOOL(value);
                
                U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
                U4DScene *scene=sceneManager->getCurrentScene();
                
                if(scene!=nullptr){
                    scene->setAnchorMouse(shouldAnchor);
                    
                }
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::pauseScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        
        if(scene!=nullptr){
            
            scene->setPauseScene(true);
            
            logger->log("Game was paused");
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::playScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        
        if(scene!=nullptr){
            
            U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
            
            if(sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()){
                //change scene state to edit mode
                scene->getSceneStateManager()->changeState(U4DScenePlayState::sharedInstance());
                
            }else if(sceneStateManager->getCurrentState()==U4DScenePlayState::sharedInstance()){
                
                scene->setPauseScene(false);
                
                logger->log("Game was resumed");
            
            }
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    //logger
    bool U4DScriptManager::loggerNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the logger_class create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
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

    //Model
    bool U4DScriptManager::modelCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(nargs==2){
                
            // self parameter is the camera create in register_cpp_classes
            gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
            gravity_value_t entityName=GET_VALUE(1);
            
            if (VALUE_ISA_STRING(entityName)) {
                
                gravity_string_t *v=(gravity_string_t *)entityName.p;
                std::string name(v->s);
            
                //get a pointer to the model if it exist
                U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
                U4DScene *scene=sceneManager->getCurrentScene();
                U4DWorld *world=scene->getGameWorld();
                
                U4DModel *model=dynamic_cast<U4DModel*>(world->searchChild(name));
                
                if(model!=nullptr){
                    // create Gravity instance and set its class to c
                    gravity_instance_t *instance = gravity_instance_new(nullptr, c);
                    
                    //store the model instance and gravity instance
                    U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
                    scriptInstanceManager->loadModelScriptInstance(model, instance);
                    
                    //Enabling the mesh manager mainly to do ray-casting intersection used while detecting if an entity
                    //is colliding.
                    model->enableMeshManager(1);
                    
                    // set cpp instance and xdata of the gravity instance
                    gravity_instance_setxdata(instance, model);
                    
                    // return instance
                    RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
                }else{
                    logger->log("Error: Could not link model. The Model %s does not exist in the world",name.c_str());
                }
                
            }else{
                logger->log("Error: Could not link model. Parameter must be of type string");
            }
        
        }else{
            logger->log("Error: Could not link model. Incorrect number of parameters");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::modelTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        // get self object which is the instance created in create function
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_instance_t *positionValue = (gravity_instance_t *)GET_VALUE(1).p;

            if (positionValue!=nullptr) {

                U4DVector3n *position = (U4DVector3n *)positionValue->xdata;

                // get xdata for both vectors
                U4DModel *model = (U4DModel *)instance->xdata;
                
                if(model!=nullptr){
                    
                    model->translateTo(*position);

                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    logger->log("Error: Could not translate the model. It does not exist");
                }
                

            }

        }else{
            logger->log("Error: Could not translate the model. Incorrect number of arguments");
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_instance_t *positionValue = (gravity_instance_t *)GET_VALUE(1).p;

            if (positionValue!=nullptr) {

                U4DVector3n *position = (U4DVector3n *)positionValue->xdata;

                // get xdata for both vectors
                U4DModel *model = (U4DModel *)instance->xdata;
                
                if(model!=nullptr){
                    
                    model->translateBy(*position);

                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    logger->log("Error: Could not translate the model. It does not exist");
                }
                

            }

        }else{
            logger->log("Error: Could not translate the model. Incorrect number of arguments");
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_instance_t *orientationValue = (gravity_instance_t *)GET_VALUE(1).p;

            if (orientationValue!=nullptr) {

                U4DVector3n *orientation = (U4DVector3n *)orientationValue->xdata;
                
                // get xdata for both vectors
                U4DModel *model = (U4DModel *)instance->xdata;
                
                if(model!=nullptr){
                    
                    model->rotateTo(orientation->x,orientation->y,orientation->z);

                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    logger->log("Error: Could not translate the model. It does not exist");
                }
                

            }

        }else{
            logger->log("Error: Could not translate the model. Incorrect number of arguments");
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
    bool U4DScriptManager::modelRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_instance_t *orientationValue = (gravity_instance_t *)GET_VALUE(1).p;

            if (orientationValue!=nullptr) {

                U4DVector3n *orientation = (U4DVector3n *)orientationValue->xdata;
                
                // get xdata for both vectors
                U4DModel *model = (U4DModel *)instance->xdata;
                
                if(model!=nullptr){
                    
                    model->rotateBy(orientation->x,orientation->y,orientation->z);

                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }else{
                    logger->log("Error: Could not translate the model. It does not exist");
                }
                

            }

        }else{
            logger->log("Error: Could not translate the model. Incorrect number of arguments");
        }

         RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
    bool U4DScriptManager::modelSetPipeline(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
    }

    bool U4DScriptManager::modelGetAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                    
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
            
            U4DVector3n position=model->getAbsolutePosition();
            
            // create a new vector type
            U4DVector3n *r = new U4DVector3n(position.x, position.y, position.z);

            // error not handled here but it should be checked
            gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

            // create a Vector3n instance
            gravity_instance_t *result = gravity_instance_new(vm, c);

            //setting the vector data to result
            gravity_instance_setxdata(result, r);

            RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelGetAbsoluteOrientation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                    
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
            
            U4DVector3n orientation=model->getAbsoluteOrientation();
            
            // create a new vector type
            U4DVector3n *r = new U4DVector3n(orientation.x, orientation.y, orientation.z);

            // error not handled here but it should be checked
            gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

            // create a Vector3n instance
            gravity_instance_t *result = gravity_instance_new(vm, c);

            //setting the vector data to result
            gravity_instance_setxdata(result, r);

            RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelGetViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
                
            U4DVector3n viewDirection=model->getViewInDirection();
            
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
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::modelSetViewInDirectionDelta(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

            gravity_instance_t *viewDirectionValue = (gravity_instance_t *)GET_VALUE(1).p;


            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;

            U4DVector3n *viewDirection = (U4DVector3n *)viewDirectionValue->xdata;

            if(model!=nullptr && viewDirection!=nullptr){

                U4DVector2n delta(viewDirection->x,viewDirection->y);
                
                delta.y*=-1.0;
                
                float deltaMagnitude=delta.magnitude();
                delta.normalize();
                
                U4DVector3n axis;
                U4DVector3n mouseDirection(delta.x,delta.y,0.0);
                
                U4DVector3n upVector(0.0,1.0,0.0);
                U4DVector3n xVector(1.0,0.0,0.0);
                
                float upDot,xDot;
                
                upDot=mouseDirection.dot(upVector);
                xDot=mouseDirection.dot(xVector);
                
                U4DVector3n v=model->getViewInDirection();
                v.normalize();
                
                if(mouseDirection.magnitude()>0){
                    
                    if(std::abs(upDot)>=std::abs(xDot)){
                        
                        
                    }else{
                        
                        if(xDot>0.0){
                            axis=upVector;
                        }else{
                            axis=upVector*-1.0;
                        }
                    }
                    
                    float angle=0.03*deltaMagnitude;
                    U4DQuaternion newOrientantion(angle,axis);
                    
                    U4DQuaternion modelOrientation=model->getAbsoluteSpaceOrientation();
                    
                    U4DQuaternion p=modelOrientation.slerp(newOrientantion, 1.0);
                    
                    model->rotateBy(p);
                }

                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }

        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }


    bool U4DScriptManager::modelSetViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){

            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;

            gravity_instance_t *viewDirectionValue = (gravity_instance_t *)GET_VALUE(1).p;


            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;

            U4DVector3n *viewDirection = (U4DVector3n *)viewDirectionValue->xdata;

            if(model!=nullptr && viewDirection!=nullptr){

                //declare an up vector
                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

                U4DVector3n viewDir=model->getEntityForwardVector();

                U4DMatrix3n m=model->getAbsoluteMatrixOrientation();

                //transform the upvector
                upVector=m*upVector;

                U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);

                float angle=(*viewDirection).angle(viewDir);

                if((*viewDirection).dot(posDir)>0.0){

                    angle*=-1.0;

                }

                U4DQuaternion q(angle,upVector);

                model->rotateTo(q);

                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }

        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelSetEntityForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
            
            gravity_instance_t *entityForwardValue = (gravity_instance_t *)GET_VALUE(1).p;
            
            if (model!=nullptr && entityForwardValue!=nullptr) {
                
                U4DVector3n *entityForwardVector = (U4DVector3n *)entityForwardValue->xdata;
                    
                //set view direction
                model->setEntityForwardVector(*entityForwardVector);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelLoadAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if (nargs==3) {
            // get self object which is the instance created in model_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            gravity_instance_t *animationInstance = (gravity_instance_t *)GET_VALUE(1).p;
            gravity_value_t animationName=GET_VALUE(2);
            
            if(instance!=nullptr && animationInstance!=nullptr && VALUE_ISA_STRING(animationName)){
                
                // get xdata
                U4DModel *model = (U4DModel *)instance->xdata;
                
                U4DAnimation *animation=(U4DAnimation *)animationInstance->xdata;
                
                gravity_string_t *v=(gravity_string_t *)animationName.p;
                
                if(model!=nullptr && animation!=nullptr){
                    model->loadAnimationToModel(animation, v->s);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                }else{
                    logger->log("Error: Could not load the animation into the model. Check whether the model or animation instances are true.");
                }
                
            }
            
            
        }else{
            logger->log("Error: Could not load the animation. Incorrect number of arguments");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::modelGetDimensions(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
     
        if(nargs==1){
                    
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DModel *model = (U4DModel *)instance->xdata;
            
            if(model!=nullptr){
                
                U4DVector3n dimensions=model->getModelDimensions();
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(dimensions.x, dimensions.y, dimensions.z);

                // error not handled here but it should be checked
                gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

                // create a Vector3n instance
                gravity_instance_t *result = gravity_instance_new(vm, c);

                //setting the vector data to result
                gravity_instance_setxdata(result, r);

                RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

//    bool U4DScriptManager::modelSetMoveDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
//
//
//        if(nargs==2){
//
//            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
//
//            gravity_instance_t *viewDirectionValue = (gravity_instance_t *)GET_VALUE(1).p;
//
//
//            // get xdata
//            U4DModel *model = (U4DModel *)instance->xdata;
//
//            U4DVector3n *viewDirection = (U4DVector3n *)viewDirectionValue->xdata;
//
//            if(model!=nullptr && viewDirection!=nullptr){
//
//                //declare an up vector
//                U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
//
//                U4DVector3n viewDir=model->getEntityForwardVector();
//
//                U4DMatrix3n m=model->getAbsoluteMatrixOrientation();
//
//                //transform the upvector
//                upVector=m*upVector;
//
//                U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
//
//                float angle=(*viewDirection).angle(viewDir);
//
//                if((*viewDirection).dot(posDir)>0.0){
//
//                    angle*=-1.0;
//
//                }
//
//                U4DQuaternion q(angle,upVector);
//
//                model->rotateTo(q);
//
//                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
//            }
//
//        }
//
//        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
//    }

    bool U4DScriptManager::modelEnableMeshManager(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_value_t meshInterval=GET_VALUE(1);
            
            if (VALUE_ISA_INT(meshInterval)) {
                
                gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
                
                // get xdata
                U4DModel *model = (U4DModel *)instance->xdata;
                
                if(model!=nullptr){
                    
                    gravity_int_t interval=meshInterval.n;
                    
                    model->enableMeshManager((int)interval);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    void U4DScriptManager::modelFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DModel *r = (U4DModel *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
    }


    //U4DAnimation
    bool U4DScriptManager::animationCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==2) {
            // self parameter is the animation create in register_cpp_classes
            gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
            gravity_instance_t *modelInstance = (gravity_instance_t *)GET_VALUE(1).p;
            
            // create Gravity instance and set its class to c
            gravity_instance_t *instance = gravity_instance_new(nullptr, c);
            
            U4DModel *model=(U4DModel *)modelInstance->xdata;
            U4DAnimation *animation = new U4DAnimation(model);
            
            U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
            scriptInstanceManager->loadAnimationScriptInstance(animation, instance);
            
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, animation);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::animationPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimation *animation = (U4DAnimation *)instance->xdata;
        
        if (animation!=nullptr) {
            animation->play();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
    }

    bool U4DScriptManager::animationStop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        bool d=false;
        
        // get xdata
        U4DAnimation *animation = (U4DAnimation *)instance->xdata;
        
        if (animation!=nullptr) {
            animation->stop();
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(d),rindex);
        
    }

    bool U4DScriptManager::getAnimationIsPlaying(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==1){
            
            // get self object which is the instance created in animation_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DAnimation *animation = (U4DAnimation *)instance->xdata;
            
            if (animation!=nullptr){
                
                bool isPlaying=animation->getAnimationIsPlaying();
                
                RETURN_VALUE(VALUE_FROM_BOOL(isPlaying),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::getCurrentKeyframe(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==1){
            
            // get self object which is the instance created in animation_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DAnimation *animation = (U4DAnimation *)instance->xdata;
            
            if (animation!=nullptr){
                
                int currentKeyframe=animation->getCurrentKeyframe();
                
                RETURN_VALUE(VALUE_FROM_INT(currentKeyframe),rindex);
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }



    bool U4DScriptManager::setPlayContinuousLoop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==2){
            
            // get self object which is the instance created in animation_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DAnimation *animation = (U4DAnimation *)instance->xdata;
            
            gravity_value_t value=GET_VALUE(1);
            
            if (animation!=nullptr && VALUE_ISA_BOOL(value)){
                
                bool playContinuously=VALUE_AS_BOOL(value);
                
                animation->setPlayContinuousLoop(playContinuously);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    void U4DScriptManager::animationFree (gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
                
        // get xdata (which is a model instance)
        U4DAnimation *r = (U4DAnimation *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
        
    }

    //Animation Manager
    bool U4DScriptManager::animationManagerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the animation manager create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        U4DAnimationManager *animationManager = new U4DAnimationManager();
        
        if(animationManager!=nullptr){
            
            U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
            
            scriptInstanceManager->loadAnimManagerScriptInstance(animationManager, instance);
            
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, animationManager);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    
    }

    bool U4DScriptManager::animationManagerSetAnimToPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==2) {
            // get self object which is the instance created in animation_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            gravity_instance_t *animationInstance = (gravity_instance_t *)GET_VALUE(1).p;
            
            
            // get xdata
            U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
            U4DAnimation *animation=(U4DAnimation*)animationInstance->xdata;
            
            if (animationManager!=nullptr && animation!=nullptr) {
                animationManager->setAnimationToPlay(animation);
            }
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::animationManagerPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
        
        if (animationManager!=nullptr) {
            animationManager->playAnimation();
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::animationManagerRemoveCurrentPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in animation_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DAnimationManager *animationManager = (U4DAnimationManager *)instance->xdata;
        
        if (animationManager!=nullptr) {
            
            animationManager->removeCurrentPlayingAnimation();
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    

    void U4DScriptManager::animationManagerFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DAnimationManager *r = (U4DAnimationManager *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
    }

    //Dynamic Actions

    bool U4DScriptManager::dynamicActionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the dynamicAction create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        gravity_instance_t *modelInstance = (gravity_instance_t *)GET_VALUE(1).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        U4DModel *model=(U4DModel *)modelInstance->xdata;
        
        if(model!=nullptr){
            
            U4DDynamicAction *dynamicAction = new U4DDynamicAction(model);
            
            U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
            scriptInstanceManager->loadDynamicActionScriptInstance(dynamicAction, instance);
            
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, dynamicAction);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
            
        }
        
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionEnableKinetic(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
        
        if (dynamicAction!=nullptr) {
            dynamicAction->enableKineticsBehavior();
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionEnableCollision(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // get xdata
        U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
        
        if (dynamicAction!=nullptr) {
            dynamicAction->enableCollisionBehavior();
            
            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
        }
        
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::dynamicActionAddForce(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("A force requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionSetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
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
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
                
        }else{
            
            logger->log("A velocity requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }


//    bool U4DScriptManager::dynamicActionApplyVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
//
//        if(nargs==3){
//
//            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
//            gravity_instance_t *velocityValue = (gravity_instance_t *)GET_VALUE(1).p;
//            gravity_value_t dtValue=GET_VALUE(2);
//
//            // get xdata
//
//            U4DDynamicAction *dynamicAction=(U4DDynamicAction *)instance->xdata;
//            U4DVector3n *velocity = (U4DVector3n *)velocityValue->xdata;
//
//            if(dynamicAction!=nullptr && velocity!=nullptr && VALUE_ISA_FLOAT(dtValue)){
//
//                gravity_float_t dt=dtValue.f;
//
//                //get mass
//                float mass=dynamicAction->getMass();
//
//                //smooth out the motion of the camera by using a Recency Weighted Average.
//                //The RWA keeps an average of the last few values, with more recent values being more
//                //significant. The bias parameter controls how much significance is given to previous values.
//                //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
//                //A bias of 1 ignores the new value altogether.
//                //float biasMotionAccumulator=0.8;
//
//                //calculate force
//                U4DEngine::U4DVector3n force=((*velocity)*mass)/dt;
//
//                //apply force
//                dynamicAction->addForce(force);
//
//                //set initial velocity to zero
//                U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//                dynamicAction->setVelocity(zero);
//
//                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
//            }
//
//        }
//
//
//        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
//    }
//
//bool U4DScriptManager::dynamicActionDecelerate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
//
//    if(nargs==2){
//
//        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
//        gravity_value_t dtValue=GET_VALUE(2);
//
//        // get xdata
//
//        U4DDynamicAction *dynamicAction=(U4DDynamicAction *)instance->xdata;
//        //U4DVector3n *velocity = (U4DVector3n *)velocityValue->xdata;
//
//        if(dynamicAction!=nullptr && VALUE_ISA_FLOAT(dtValue)){
//
//            dynamicAction->setAwake(true);
//            U4DVector3n velocity=dynamicAction->getVelocity();
//            gravity_float_t dt=dtValue.f;
//
//            //get mass
//            float mass=dynamicAction->getMass();
//
//            //smooth out the motion of the camera by using a Recency Weighted Average.
//            //The RWA keeps an average of the last few values, with more recent values being more
//            //significant. The bias parameter controls how much significance is given to previous values.
//            //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
//            //A bias of 1 ignores the new value altogether.
//            //float biasMotionAccumulator=0.8;
//
//            //calculate force
//            U4DEngine::U4DVector3n force=((velocity)*mass)/dt;
//
//            force*=0.25;
//
//            //apply force
//            dynamicAction->addForce(force);
//
//            //set initial velocity to zero
//            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//            dynamicAction->setVelocity(zero);
//
//            RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
//        }
//
//    }
//
//
//    RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
//}
//
//    bool U4DScriptManager::dynamicActionApplyRollVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
//
//        if(nargs==3){
//
//            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
//            gravity_instance_t *velocityValue = (gravity_instance_t *)GET_VALUE(1).p;
//            gravity_value_t dtValue=GET_VALUE(2);
//
//            // get xdata
//
//            U4DDynamicAction *dynamicAction=(U4DDynamicAction *)instance->xdata;
//            U4DVector3n *velocity = (U4DVector3n *)velocityValue->xdata;
//
//            if(dynamicAction!=nullptr && velocity!=nullptr && VALUE_ISA_FLOAT(dtValue)){
//
//                gravity_float_t dt=dtValue.f;
//
//                //get mass
//                float mass=dynamicAction->getMass();
//
//                //smooth out the motion of the camera by using a Recency Weighted Average.
//                //The RWA keeps an average of the last few values, with more recent values being more
//                //significant. The bias parameter controls how much significance is given to previous values.
//                //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
//                //A bias of 1 ignores the new value altogether.
//                //float biasMotionAccumulator=0.8;
//
//               // motionAccumulator=motionAccumulator*biasMotionAccumulator+(*velocity)*(1.0-biasMotionAccumulator);
//
//                //calculate force
//                U4DEngine::U4DVector3n force=((*velocity)*mass)/dt;
//
//                //apply force
//                dynamicAction->addForce(force);
//
//                //apply moment to ball
//                U4DVector3n upAxis(0.0,1.0/2.0,0.0);
//
//                force*=0.25;
//
//                U4DVector3n moment=upAxis.cross(force);
//
//                dynamicAction->addMoment(moment);
//
//                //set initial velocity to zero
//                U4DVector3n zero(0.0,0.0,0.0);
//                dynamicAction->setVelocity(zero);
//                dynamicAction->setAngularVelocity(zero);
//
//                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
//            }
//
//        }
//
//
//        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
//
//    }
//
//    bool U4DScriptManager::dynamicActionApplyRollDecelerate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
//
//        if(nargs==2){
//
//            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
//            gravity_value_t dtValue=GET_VALUE(1);
//
//            // get xdata
//
//            U4DDynamicAction *dynamicAction=(U4DDynamicAction *)instance->xdata;
//            //U4DVector3n *velocity = (U4DVector3n *)velocityValue->xdata;
//
//            if(dynamicAction!=nullptr && VALUE_ISA_FLOAT(dtValue)){
//
//                dynamicAction->setAwake(true);
//
//                U4DVector3n velocity=dynamicAction->getVelocity();
//
//                gravity_float_t dt=dtValue.f;
//
//                //get mass
//                float mass=dynamicAction->getMass();
//
//                //smooth out the motion of the camera by using a Recency Weighted Average.
//                //The RWA keeps an average of the last few values, with more recent values being more
//                //significant. The bias parameter controls how much significance is given to previous values.
//                //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
//                //A bias of 1 ignores the new value altogether.
//                //float biasMotionAccumulator=0.8;
//
//                //motionAccumulator=motionAccumulator*biasMotionAccumulator+velocity*(1.0-biasMotionAccumulator);
//
//                //calculate force
//                U4DEngine::U4DVector3n force=(velocity*mass)/dt;
//
//                //apply force
//                dynamicAction->addForce(force);
//
//                //apply moment to ball
//                U4DVector3n upAxis(0.0,1.0/2.0,0.0);
//
//                force*=0.25;
//
//                U4DVector3n moment=upAxis.cross(force);
//
//                dynamicAction->addMoment(moment);
//
//                //set initial velocity to zero
//                U4DVector3n zero(0.0,0.0,0.0);
//                dynamicAction->setVelocity(zero);
//                dynamicAction->setAngularVelocity(zero);
//
//                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
//            }
//
//        }
//
//
//        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
//
//    }


    bool U4DScriptManager::dynamicActionSetAwake(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        
        gravity_value_t value=GET_VALUE(1);
        
        if (nargs==2 && VALUE_ISA_BOOL(value)) {
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                bool awakeValue=VALUE_AS_BOOL(value);
                dynamicAction->setAwake(awakeValue);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::dynamicActionGetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                    
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if(dynamicAction!=nullptr){
             
                U4DVector3n velocity=dynamicAction->getVelocity();
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(velocity.x, velocity.y, velocity.z);

                // error not handled here but it should be checked
                gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

                // create a Vector3n instance
                gravity_instance_t *result = gravity_instance_new(vm, c);

                //setting the vector data to result
                gravity_instance_setxdata(result, r);

                RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionSetCollisionFilterCategory(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_value_t category=GET_VALUE(1);
            
            if (VALUE_ISA_INT(category)) {
                
                gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
                
                // get xdata
                U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
                
                if(dynamicAction!=nullptr){
                    
                    gravity_int_t collisionCategory=category.n;
                    
                    dynamicAction->setCollisionFilterCategory((int)collisionCategory);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionSetCollisionFilterMask(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_value_t mask=GET_VALUE(1);
            
            if (VALUE_ISA_INT(mask)) {
                
                gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
                
                // get xdata
                U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
                
                if(dynamicAction!=nullptr){
                    
                    gravity_int_t collisionMask=mask.n;
                    
                    dynamicAction->setCollisionFilterMask((int)collisionMask);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionAddMoment(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_instance_t *v = (gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata for both vectors
            U4DVector3n *moment = (U4DVector3n *)v->xdata;
        
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->addMoment(*moment);
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        if (nargs!=2) {
            
            logger->log("A force requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionSetIsCollisionSensor(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_value_t value=GET_VALUE(1);
        
        if (nargs==2 && VALUE_ISA_BOOL(value)) {
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                bool sensorValue=VALUE_AS_BOOL(value);
                dynamicAction->setIsCollisionSensor(sensorValue);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::dynamicActionSetCollidingTag(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_value_t tag=GET_VALUE(1);
        
        if (nargs==2 && VALUE_ISA_STRING(tag)) {
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                gravity_string_t *t=(gravity_string_t *)tag.p;
                std::string collisionTag(t->s);
                
                dynamicAction->setCollidingTag(collisionTag);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::dynamicActionInitMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
                    
            gravity_value_t massValue=GET_VALUE(1);
            
            if (VALUE_ISA_FLOAT(massValue)) {
                
                gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
                // get xdata
                U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
                
                if(dynamicAction!=nullptr){
                    
                    gravity_float_t mass=massValue.f;
                    
                    dynamicAction->initMass(mass);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionGetMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if(dynamicAction!=nullptr){
                
                float mass=dynamicAction->getMass();
                
                RETURN_VALUE(VALUE_FROM_FLOAT(mass),rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionGetModelHasCollided(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if(dynamicAction!=nullptr){
                
                bool collided=dynamicAction->getModelHasCollided();
                
                RETURN_VALUE(VALUE_FROM_BOOL(collided),rindex);
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::dynamicActionGetCollisionListTags(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if(dynamicAction!=nullptr){
                
                std::list<std::string> collisionListTags;
                
                for(auto n:dynamicAction->getCollisionList()){
                    collisionListTags.push_back(n->getCollidingTag());
                }
                
                //convert c++ list to gravity list
                //create a new list
                gravity_list_t *l=gravity_list_new(NULL, (int)collisionListTags.size());
                
                for(auto const &n:collisionListTags){
                    
                    gravity_value_t collidingModelTag=VALUE_FROM_CSTRING(vm, n.c_str());
                    
                    //load the vector components into the list
                    marray_push(gravity_value_t, l->array, collidingModelTag);
                    
                }
                
                // transfer newly allocated object to the VM
                gravity_vm_transfer(vm, (gravity_object_t*) l);
                
                RETURN_VALUE(VALUE_FROM_OBJECT(l), rindex);
            }
            
        }
        
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    

    bool U4DScriptManager::dynamicActionInitAsPlatform(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_value_t value=GET_VALUE(1);
            
            if (VALUE_ISA_BOOL(value)) {
                
                gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
                // get xdata
                U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
                
                if(dynamicAction!=nullptr){
                    
                    bool isPlatform=VALUE_AS_BOOL(value);
                    
                    dynamicAction->initAsPlatform(isPlatform);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionResumeCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->resumeCollisionBehavior();
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionPauseCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==1){
                
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->pauseCollisionBehavior();
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::dynamicActionSetDragCoefficient(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        // get self object which is the instance created in dynamicAction_create function
        gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            gravity_instance_t *v = (gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata for both vectors
            U4DVector3n *coeffValue = (U4DVector3n *)v->xdata;
            U4DVector2n dragCoeff(coeffValue->x,coeffValue->y);
            
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr) {
                
                dynamicAction->setDragCoefficient(dragCoeff);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
                
        }else{
            
            logger->log("A velocity requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }
    bool U4DScriptManager::dynamicActionSetAngularVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
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
                
                dynamicAction->setAngularVelocity(*velocity);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
                
        }else{
            
            logger->log("A velocity requires a vector component.");
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }


    bool U4DScriptManager::dynamicActionInitInertiaTensorType(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // check for optional parameters here (if you need to process a more complex constructor)
        if (nargs==2) {
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            
            gravity_value_t inertiaTensorValue=GET_VALUE(1);
        
            // get xdata
            U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
            
            if (dynamicAction!=nullptr && VALUE_ISA_INT(inertiaTensorValue)) {
                
                //int inertiaValue=inertiaTensorValue.n;
                
                dynamicAction->initInertiaTensorType(U4DEngine::sphericalInertia);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
            
                
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
        
        /*
         if (VALUE_ISA_FLOAT(massValue)) {
             
             gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
             // get xdata
             U4DDynamicAction *dynamicAction = (U4DDynamicAction *)instance->xdata;
             
             if(dynamicAction!=nullptr){
                 
                 gravity_float_t mass=massValue.f;
         */
    }

    bool U4DScriptManager::dynamicActionSetGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
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

    void U4DScriptManager::dynamicActionFree (gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DDynamicAction *r = (U4DDynamicAction *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
    }

    //camera
    bool U4DScriptManager::cameraNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        // self parameter is the camera create in register_cpp_classes
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
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

    bool U4DScriptManager::setCameraAsThirdPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==3) {
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            gravity_value_t entityName=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            U4DScene *scene=sceneManager->getCurrentScene();
            U4DWorld *world=scene->getGameWorld();
            
            if (VALUE_ISA_STRING(entityName) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entityName.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                U4DEntity *entity=world->searchChild(name);
                
                if(entity!=nullptr){
                    
                    U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
                    
                    //Instantiate the camera interface and the type of camera you desire
                    U4DCameraInterface *cameraThirdPerson=U4DCameraThirdPerson::sharedInstance();
                    
                    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
                    cameraThirdPerson->setParameters(model,offset->x,offset->y,offset->z);
                    
                    //Line 3. set the camera behavior
                    camera->setCameraBehavior(cameraThirdPerson);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::setCameraAsFirstPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==3) {
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            gravity_value_t entityName=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            U4DScene *scene=sceneManager->getCurrentScene();
            U4DWorld *world=scene->getGameWorld();
            
            if (VALUE_ISA_STRING(entityName) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entityName.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                U4DEntity *entity=world->searchChild(name);
                
                if(entity!=nullptr){
                    
                    U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
                    
                    //Instantiate the camera interface and the type of camera you desire
                    U4DCameraInterface *cameraFirstPerson=U4DCameraFirstPerson::sharedInstance();
                    
                    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
                    
                    cameraFirstPerson->setParameters(model,offset->x,offset->y,offset->z);
                    
                    //set the camera behavior
                    
                    camera->setCameraBehavior(cameraFirstPerson);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    bool U4DScriptManager::setCameraAsBasicFollow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if (nargs==3) {
            
            U4DCamera *camera = U4DCamera::sharedInstance();
            gravity_value_t entityName=GET_VALUE(1);
            gravity_instance_t *offsetValue = (gravity_instance_t *)GET_VALUE(2).p;
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            U4DScene *scene=sceneManager->getCurrentScene();
            U4DWorld *world=scene->getGameWorld();
            
            if (VALUE_ISA_STRING(entityName) && (offsetValue!=nullptr)) {
                
                gravity_string_t *v=(gravity_string_t *)entityName.p;
                std::string name(v->s);
                
                U4DVector3n *offset = (U4DVector3n *)offsetValue->xdata;
                
                U4DEntity *entity=world->searchChild(name);
                
                if(entity!=nullptr){
                    
                    U4DModel *model=reinterpret_cast<U4DModel*>(entity->pModel);
                    
                    //Instantiate the camera interface and the type of camera you desire
                    U4DCameraInterface *cameraBasicFollow=U4DCameraBasicFollow::sharedInstance();

                    //Set the parameters for the camera. Such as which model the camera will target, and the offset positions
                    cameraBasicFollow->setParameters(model,offset->x,offset->y,offset->z);

                    //set the camera behavior
                    camera->setCameraBehavior(cameraBasicFollow);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                    
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    void U4DScriptManager::cameraFree (gravity_vm *vm, gravity_object_t *obj){
        
    }

    //AI Steering
    bool U4DScriptManager::aiSeekNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        
        U4DSeek *aiSeek = new U4DSeek();
        
        if(aiSeek!=nullptr){
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, aiSeek);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
        
    bool U4DScriptManager::aiSeekGetSteering(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==3){
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DSeek *seek = (U4DSeek *)instance->xdata;
            
            //get the dynamic action instance
            gravity_instance_t *d = (gravity_instance_t *)GET_VALUE(1).p;
            
            U4DDynamicAction *dynamicAction=(U4DDynamicAction*)d->xdata;
            
            //get the target position
            gravity_instance_t *p = (gravity_instance_t *)GET_VALUE(2).p;
            
            // get xdata for both vectors
            U4DVector3n *targetPosition = (U4DVector3n *)p->xdata;
            
            if(seek!=nullptr && dynamicAction!=nullptr && targetPosition!=nullptr){
                
                U4DVector3n velocity=(*seek).getSteering(dynamicAction, *targetPosition);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(velocity.x, velocity.y, velocity.z);

                // error not handled here but it should be checked
                gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

                // create a Vector3n instance
                gravity_instance_t *result = gravity_instance_new(vm, c);

                //setting the vector data to result
                gravity_instance_setxdata(result, r);

                RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
                
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::aiSeekSetMaxSpeed(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DSeek *seek = (U4DSeek *)instance->xdata;
            
            gravity_value_t speedValue=GET_VALUE(1);
            
            if(seek!=nullptr && VALUE_ISA_FLOAT(speedValue)){
                
                gravity_float_t speed=speedValue.f;

                seek->setMaxSpeed(speed);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }

    void U4DScriptManager::aiSeekFree(gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DSeek *r = (U4DSeek *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
    }

    bool U4DScriptManager::aiArriveNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        
        U4DArrive *aiArrive = new U4DArrive();
        
        if(aiArrive!=nullptr){
            // set cpp instance and xdata of the gravity instance
            gravity_instance_setxdata(instance, aiArrive);
            
            // return instance
            RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
    bool U4DScriptManager::aiArriveGetSteering(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==3){
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DArrive *arrive = (U4DArrive *)instance->xdata;
            
            //get the dynamic action instance
            gravity_instance_t *d = (gravity_instance_t *)GET_VALUE(1).p;
            
            U4DDynamicAction *dynamicAction=(U4DDynamicAction*)d->xdata;
            
            //get the target position
            gravity_instance_t *p = (gravity_instance_t *)GET_VALUE(2).p;
            
            // get xdata for both vectors
            U4DVector3n *targetPosition = (U4DVector3n *)p->xdata;
            
            if(arrive!=nullptr && dynamicAction!=nullptr && targetPosition!=nullptr){
                
                U4DVector3n velocity=(*arrive).getSteering(dynamicAction, *targetPosition);
                
                // create a new vector type
                U4DVector3n *r = new U4DVector3n(velocity.x, velocity.y, velocity.z);

                // error not handled here but it should be checked
                gravity_class_t *c = VALUE_AS_CLASS(gravity_vm_getvalue(vm, "U4DVector3n", strlen("U4DVector3n")));

                // create a Vector3n instance
                gravity_instance_t *result = gravity_instance_new(vm, c);

                //setting the vector data to result
                gravity_instance_setxdata(result, r);

                RETURN_VALUE(VALUE_FROM_OBJECT(result), rindex);
                
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
    }
    bool U4DScriptManager::aiArriveSetMaxSpeed(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            // get self object which is the instance created in dynamicAction_create function
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DArrive *arrive = (U4DArrive *)instance->xdata;
            
            gravity_value_t speedValue=GET_VALUE(1);
            
            if(arrive!=nullptr && VALUE_ISA_FLOAT(speedValue)){
                
                gravity_float_t speed=speedValue.f;

                arrive->setMaxSpeed(speed);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                
            }
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
    void U4DScriptManager::aiArriveFree (gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a model instance)
        U4DArrive *r = (U4DArrive *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
        
    }

    

    //Team
    bool U4DScriptManager::teamNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_class_t *c = (gravity_class_t *)GET_VALUE(0).p;
        
        // create Gravity instance and set its class to c
        gravity_instance_t *instance = gravity_instance_new(nullptr, c);
        
        gravity_value_t teamName=GET_VALUE(1);
        
        if (VALUE_ISA_STRING(teamName)) {
            
            gravity_string_t *v=(gravity_string_t *)teamName.p;
            std::string name(v->s);
            
            U4DTeam *team = new U4DTeam(name);
            
            if(team!=nullptr){
                // set cpp instance and xdata of the gravity instance
                gravity_instance_setxdata(instance, team);
                
                //store the team instance and gravity instance
                U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
                scriptInstanceManager->loadTeamScriptInstance(team, instance);
                
                // return instance
                RETURN_VALUE(VALUE_FROM_OBJECT(instance), rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::teamAddPlayer(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        if(nargs==2){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            gravity_value_t playerName=GET_VALUE(1);
            
            // get xdata
            U4DTeam *team = (U4DTeam *)instance->xdata;
            
            if (VALUE_ISA_STRING(playerName) && team!=nullptr) {
                
                gravity_string_t *v=(gravity_string_t *)playerName.p;
                std::string name(v->s);
                
                U4DPlayer *player=dynamic_cast<U4DPlayer*>(world->searchChild(name));
                
                if(player!=nullptr){
                    team->addPlayer(player);
                    
                    RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
                }
                
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::teamSetOppositeTeam(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        if(nargs==2){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            gravity_instance_t *oppositeTeamInstance=(gravity_instance_t *)GET_VALUE(1).p;
            
            // get xdata
            U4DTeam *team = (U4DTeam *)instance->xdata;
            U4DTeam *oppositeTeam=(U4DTeam *)oppositeTeamInstance->xdata;
            
            if (oppositeTeam!=nullptr && team!=nullptr) {
                
                team->setOppositeTeam(oppositeTeam);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }
    bool U4DScriptManager::teamSetActivePlayer(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        if(nargs==2){
            
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            gravity_value_t playerName=GET_VALUE(1);
            
            // get xdata
            U4DTeam *team = (U4DTeam *)instance->xdata;
            
            if (VALUE_ISA_STRING(playerName) && team!=nullptr) {
                
                gravity_string_t *v=(gravity_string_t *)playerName.p;
                std::string name(v->s);
                
                U4DPlayer *player=dynamic_cast<U4DPlayer*>(world->searchChild(name));
                
                team->setActivePlayer(player);
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }
        
        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    bool U4DScriptManager::teamSetAITeam(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex){
        
        gravity_value_t value=GET_VALUE(1);
        
        if (nargs==2 && VALUE_ISA_BOOL(value)) {
            gravity_instance_t *instance = (gravity_instance_t *)GET_VALUE(0).p;
            // get xdata
            U4DTeam *team = (U4DTeam *)instance->xdata;
            
            if (team!=nullptr) {
                bool aiValue=VALUE_AS_BOOL(value);
                team->aiTeam=aiValue;
                
                RETURN_VALUE(VALUE_FROM_BOOL(true),rindex);
            }
            
        }

        RETURN_VALUE(VALUE_FROM_BOOL(false),rindex);
        
    }

    void U4DScriptManager::teamFree (gravity_vm *vm, gravity_object_t *obj){
        
        gravity_instance_t *instance = (gravity_instance_t *)obj;
        
        // get xdata (which is a team instance)
        U4DTeam *r = (U4DTeam *)instance->xdata;
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
        
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
         gravity_value_t value = GET_VALUE(2);

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
         gravity_value_t value = GET_VALUE(2);

         // decode value
         float d = 0.0f;
        if (VALUE_ISA_FLOAT(value)){
            d = VALUE_AS_FLOAT(value);
        }else if (VALUE_ISA_INT(value)){
            d = double(VALUE_AS_INT(value));
        }
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
         gravity_value_t value = GET_VALUE(2);

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
        
        if(r!=nullptr){
            // explicitly free memory
            delete r;
        }
        
    }


    bool U4DScriptManager::loadScript(std::string uScriptPath){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        
        scriptInstanceManager->removeAllScriptInstances();
        
        logger->log("Loading script %s",uScriptPath.c_str());
    
        if(director->getScriptRunTimeError()==true){
        //we have to initialize the script again if there was a script-runtime error. But first we need to free all user inputs objects created such as lists and maps
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
        
        userInputList=gravity_list_new(nullptr, 14);
        //if (loadScript(uScriptPath)) {
            
         
            return true;
        //}
        
        //return false;
        
    }

    void U4DScriptManager::freeObjects(gravity_vm *vm, gravity_object_t *obj){
        
        
        
    }

    void U4DScriptManager::registerClasses(gravity_vm *vm){
            
        //untold
        gravity_class_t *worldClass = gravity_class_new_pair(vm, "U4DWorld", NULL, 0, 0);
        gravity_class_t *worldClassMeta = gravity_class_get_meta(worldClass);
        
        gravity_class_bind(worldClassMeta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(worldCreate));
        gravity_class_bind(worldClass, "loadModel", NEW_CLOSURE_VALUE(loadModel));
        gravity_class_bind(worldClass, "removeModel", NEW_CLOSURE_VALUE(removeModel));
        gravity_class_bind(worldClass, "anchorMouse", NEW_CLOSURE_VALUE(anchorMouse));
        gravity_class_bind(worldClass, "pauseScene", NEW_CLOSURE_VALUE(pauseScene));
        gravity_class_bind(worldClass, "playScene", NEW_CLOSURE_VALUE(playScene));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "U4DWorld", VALUE_FROM_OBJECT(worldClass));
        
        //model
        gravity_class_t *model_class = gravity_class_new_pair(vm, "U4DModel", NULL, 0, 0);
        gravity_class_t *model_class_meta = gravity_class_get_meta(model_class);
        
        gravity_class_bind(model_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(modelCreate));
        gravity_class_bind(model_class, "translateTo", NEW_CLOSURE_VALUE(modelTranslateTo));
        gravity_class_bind(model_class,"getAbsolutePosition",NEW_CLOSURE_VALUE(modelGetAbsolutePosition));
        gravity_class_bind(model_class, "translateBy", NEW_CLOSURE_VALUE(modelTranslateBy));
        gravity_class_bind(model_class, "rotateTo", NEW_CLOSURE_VALUE(modelRotateTo));
        gravity_class_bind(model_class, "rotateBy", NEW_CLOSURE_VALUE(modelRotateBy));
        gravity_class_bind(model_class, "getAbsoluteOrientation", NEW_CLOSURE_VALUE(modelGetAbsoluteOrientation));
        gravity_class_bind(model_class, "getViewInDirection", NEW_CLOSURE_VALUE(modelGetViewInDirection));
        gravity_class_bind(model_class, "setViewInDirection", NEW_CLOSURE_VALUE(modelSetViewInDirection));
        gravity_class_bind(model_class, "setViewInDirectionDelta", NEW_CLOSURE_VALUE(modelSetViewInDirectionDelta));
        
        gravity_class_bind(model_class, "setEntityForwardVector", NEW_CLOSURE_VALUE(modelSetEntityForwardVector));
        
        gravity_class_bind(model_class, "getModelDimensions", NEW_CLOSURE_VALUE(modelGetDimensions));
        
        
        gravity_class_bind(model_class, "setPipeline", NEW_CLOSURE_VALUE(modelSetPipeline));
        gravity_class_bind(model_class, "loadAnimationToModel", NEW_CLOSURE_VALUE(modelLoadAnimation));
        gravity_class_bind(model_class, "enableMeshManager", NEW_CLOSURE_VALUE(modelEnableMeshManager));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DModel", VALUE_FROM_OBJECT(model_class));
        
        //animation
        gravity_class_t *animation_class = gravity_class_new_pair(vm, "U4DAnimation", NULL, 0, 0);
        gravity_class_t *animation_class_meta = gravity_class_get_meta(animation_class);
        
        gravity_class_bind(animation_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(animationCreate));
        gravity_class_bind(animation_class, "play", NEW_CLOSURE_VALUE(animationPlay));
        gravity_class_bind(animation_class, "stop", NEW_CLOSURE_VALUE(animationStop));
        
        gravity_class_bind(animation_class, "getAnimationIsPlaying", NEW_CLOSURE_VALUE(getAnimationIsPlaying));
        gravity_class_bind(animation_class, "getCurrentKeyframe", NEW_CLOSURE_VALUE(getCurrentKeyframe));
        gravity_class_bind(animation_class, "setPlayContinuousLoop", NEW_CLOSURE_VALUE(setPlayContinuousLoop));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DAnimation", VALUE_FROM_OBJECT(animation_class));
        
        //animation manager
        gravity_class_t *animationManager_class = gravity_class_new_pair(vm, "U4DAnimationManager", NULL, 0, 0);
                
        gravity_class_t *animationManager_class_meta = gravity_class_get_meta(animationManager_class);
        
        gravity_class_bind(animationManager_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(animationManagerCreate));
        
        gravity_class_bind(animationManager_class, "setAnimationToPlay", NEW_CLOSURE_VALUE(animationManagerSetAnimToPlay));
        
        gravity_class_bind(animationManager_class, "playAnimation", NEW_CLOSURE_VALUE(animationManagerPlayAnim));
        
        gravity_class_bind(animationManager_class, "removeCurrentPlayingAnimation", NEW_CLOSURE_VALUE(animationManagerRemoveCurrentPlayAnim));
        
        // register model class inside VM
        gravity_vm_setvalue(vm, "U4DAnimationManager", VALUE_FROM_OBJECT(animationManager_class));
        
        //dynamic action
        gravity_class_t *dynamicAction_class = gravity_class_new_pair(vm, "U4DDynamicAction", NULL, 0, 0);
        gravity_class_t *dynamicAction_class_meta = gravity_class_get_meta(dynamicAction_class);
        
        gravity_class_bind(dynamicAction_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(dynamicActionCreate));
        gravity_class_bind(dynamicAction_class, "enableKineticsBehavior", NEW_CLOSURE_VALUE(dynamicActionEnableKinetic));
        gravity_class_bind(dynamicAction_class, "enableCollisionBehavior", NEW_CLOSURE_VALUE(dynamicActionEnableCollision));
        
        gravity_class_bind(dynamicAction_class, "addForce", NEW_CLOSURE_VALUE(dynamicActionAddForce));
        gravity_class_bind(dynamicAction_class, "setVelocity", NEW_CLOSURE_VALUE(dynamicActionSetVelocity));
        gravity_class_bind(dynamicAction_class, "setGravity", NEW_CLOSURE_VALUE(dynamicActionSetGravity));
                
        
        gravity_class_bind(dynamicAction_class, "setAwake", NEW_CLOSURE_VALUE(dynamicActionSetAwake));
        gravity_class_bind(dynamicAction_class, "getVelocity", NEW_CLOSURE_VALUE(dynamicActionGetVelocity));
        gravity_class_bind(dynamicAction_class, "setCollisionFilterCategory", NEW_CLOSURE_VALUE(dynamicActionSetCollisionFilterCategory));
        gravity_class_bind(dynamicAction_class, "setCollisionFilterMask", NEW_CLOSURE_VALUE(dynamicActionSetCollisionFilterMask));
        
        
        gravity_class_bind(dynamicAction_class, "addMoment", NEW_CLOSURE_VALUE(dynamicActionAddMoment));
        gravity_class_bind(dynamicAction_class, "setIsCollisionSensor", NEW_CLOSURE_VALUE(dynamicActionSetIsCollisionSensor));
        gravity_class_bind(dynamicAction_class, "setCollidingTag", NEW_CLOSURE_VALUE(dynamicActionSetCollidingTag));
        gravity_class_bind(dynamicAction_class, "getMass", NEW_CLOSURE_VALUE(dynamicActionGetMass));
        gravity_class_bind(dynamicAction_class, "getModelHasCollided", NEW_CLOSURE_VALUE(dynamicActionGetModelHasCollided));
        
        
        gravity_class_bind(dynamicAction_class, "getCollisionListTags", NEW_CLOSURE_VALUE(dynamicActionGetCollisionListTags));
        gravity_class_bind(dynamicAction_class, "initMass", NEW_CLOSURE_VALUE(dynamicActionInitMass));
        gravity_class_bind(dynamicAction_class, "initAsPlatform", NEW_CLOSURE_VALUE(dynamicActionInitAsPlatform));
        gravity_class_bind(dynamicAction_class, "resumeCollisionBehavior", NEW_CLOSURE_VALUE(dynamicActionResumeCollisionBehavior));
        gravity_class_bind(dynamicAction_class, "pauseCollisionBehavior", NEW_CLOSURE_VALUE(dynamicActionPauseCollisionBehavior));
        

        gravity_class_bind(dynamicAction_class, "setAngularVelocity", NEW_CLOSURE_VALUE(dynamicActionSetAngularVelocity));
        gravity_class_bind(dynamicAction_class, "setDragCoefficient", NEW_CLOSURE_VALUE(dynamicActionSetDragCoefficient));
        gravity_class_bind(dynamicAction_class, "initInertiaTensorType", NEW_CLOSURE_VALUE(dynamicActionInitInertiaTensorType));
        
        
        // register dynamic action  class inside VM
        gravity_vm_setvalue(vm, "U4DDynamicAction", VALUE_FROM_OBJECT(dynamicAction_class));
        
        //AI Seek
        gravity_class_t *aiSeek_class = gravity_class_new_pair(vm, "U4DSeek", NULL, 0, 0);
        gravity_class_t *aiSeek_class_meta = gravity_class_get_meta(aiSeek_class);
        
        gravity_class_bind(aiSeek_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(aiSeekNew));
        
        gravity_class_bind(aiSeek_class, "getSteering", NEW_CLOSURE_VALUE(aiSeekGetSteering));
        gravity_class_bind(aiSeek_class, "setMaxSpeed", NEW_CLOSURE_VALUE(aiSeekSetMaxSpeed));
        
        //register seek class inside the vm
        gravity_vm_setvalue(vm, "U4DSeek", VALUE_FROM_OBJECT(aiSeek_class));
        
        //AI Arrive
        gravity_class_t *aiArrive_class = gravity_class_new_pair(vm, "U4DArrive", NULL, 0, 0);
        gravity_class_t *aiArrive_class_meta = gravity_class_get_meta(aiArrive_class);
        
        gravity_class_bind(aiArrive_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(aiArriveNew));
        
        gravity_class_bind(aiArrive_class, "getSteering", NEW_CLOSURE_VALUE(aiArriveGetSteering));
        gravity_class_bind(aiArrive_class, "setMaxSpeed", NEW_CLOSURE_VALUE(aiArriveSetMaxSpeed));
        
        //register seek class inside the vm
        gravity_vm_setvalue(vm, "U4DArrive", VALUE_FROM_OBJECT(aiArrive_class));
        
        
        //Team
        gravity_class_t *team_class = gravity_class_new_pair(vm, "U4DTeam", NULL, 0, 0);
        gravity_class_t *team_class_meta = gravity_class_get_meta(team_class);
        
        gravity_class_bind(team_class_meta, GRAVITY_INTERNAL_EXEC_NAME, NEW_CLOSURE_VALUE(teamNew));
        
        gravity_class_bind(team_class, "addPlayer", NEW_CLOSURE_VALUE(teamAddPlayer));
        gravity_class_bind(team_class, "setOppositeTeam", NEW_CLOSURE_VALUE(teamSetOppositeTeam));
        gravity_class_bind(team_class, "setActivePlayer", NEW_CLOSURE_VALUE(teamSetActivePlayer));
        gravity_class_bind(team_class, "setAsAITeam", NEW_CLOSURE_VALUE(teamSetAITeam));
        
        
        
        //register team class inside the vm
        gravity_vm_setvalue(vm, "U4DTeam", VALUE_FROM_OBJECT(team_class));
        
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
        gravity_class_bind(camera_class, "setCameraAsThirdPerson", NEW_CLOSURE_VALUE(setCameraAsThirdPerson));
        gravity_class_bind(camera_class, "setCameraAsFirstPerson", NEW_CLOSURE_VALUE(setCameraAsFirstPerson));
        gravity_class_bind(camera_class, "setCameraAsBasicFollow", NEW_CLOSURE_VALUE(setCameraAsBasicFollow));
        
        // register logger class inside VM
        gravity_vm_setvalue(vm, "U4DCamera", VALUE_FROM_OBJECT(camera_class));
        
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

                gravity_value_t inputElementType=VALUE_FROM_INT(controllerInputMessage.inputElementType);
                gravity_value_t inputElementAction=VALUE_FROM_INT(controllerInputMessage.inputElementAction);
                
                 //joystick
                 //prepare joystick data into a list before inserting it into a map
                 gravity_value_t joystickDirX = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.x);
                 gravity_value_t joystickDirY = VALUE_FROM_FLOAT(controllerInputMessage.joystickDirection.y);
             
                 //inputposition
                 gravity_value_t inputPositionX = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.x);
                 gravity_value_t inputPositionY = VALUE_FROM_FLOAT(controllerInputMessage.inputPosition.y);

                //previousMousePosition
                 gravity_value_t previousMousePositionX = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.x);
                 gravity_value_t previousMousePositionY = VALUE_FROM_FLOAT(controllerInputMessage.previousMousePosition.y);
                
                //mouseDeltaPosition
                
                 gravity_value_t mouseDeltaPositionX = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.x);
                 gravity_value_t mouseDeltaPositionY = VALUE_FROM_FLOAT(controllerInputMessage.mouseDeltaPosition.y);
                

                gravity_value_t joystickChangeDirection=VALUE_FROM_BOOL(controllerInputMessage.joystickChangeDirection);

                //mouseChangeDirection
                gravity_value_t mouseChangeDirection=VALUE_FROM_BOOL(controllerInputMessage.mouseChangeDirection);
                
                //arrowKeyDirection
                 gravity_value_t arrowKeyDirectionX = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.x);
                 gravity_value_t arrowKeyDirectionY = VALUE_FROM_FLOAT(controllerInputMessage.arrowKeyDirection.y);

                
                marray_push(gravity_value_t, userInputList->array, inputElementType);
                marray_push(gravity_value_t, userInputList->array, inputElementAction);
                
                marray_push(gravity_value_t, userInputList->array, joystickDirX);
                marray_push(gravity_value_t, userInputList->array, joystickDirY);
                
                marray_push(gravity_value_t, userInputList->array, inputPositionX);
                marray_push(gravity_value_t, userInputList->array, inputPositionY);
                
                marray_push(gravity_value_t, userInputList->array, previousMousePositionX);
                marray_push(gravity_value_t, userInputList->array, previousMousePositionY);
                
                marray_push(gravity_value_t, userInputList->array, mouseDeltaPositionX);
                marray_push(gravity_value_t, userInputList->array, mouseDeltaPositionY);
                
                marray_push(gravity_value_t, userInputList->array, joystickChangeDirection);
                marray_push(gravity_value_t, userInputList->array, mouseChangeDirection);
                
                marray_push(gravity_value_t, userInputList->array, arrowKeyDirectionX);
                marray_push(gravity_value_t, userInputList->array, arrowKeyDirectionY);
                

//            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionX);
//            marray_push(gravity_value_t, arrowKeyDirectionList->array, arrowKeyDirectionY);

//             //elementUIName
//             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[elementUIName],VALUE_FROM_STRING(vm, controllerInputMessage.elementUIName.c_str(), (int)controllerInputMessage.elementUIName.length()));
//
//             //dataValue
//             gravity_map_insert(vm,controllerInputMessageMap,userInputElementArray[dataValue],VALUE_FROM_FLOAT(controllerInputMessage.dataValue));

            
             gravity_value_t controllerInputData=VALUE_FROM_OBJECT(userInputList);
             gravity_value_t params[] = {controllerInputData};

             // execute user-input closure
             if (gravity_vm_runclosure (vm, userInput_closure, VALUE_FROM_NULL, params, 1)) {
                 
                 
             }
                
                removeItemsInList(userInputList);
                
                
            }
                
            
            
        }
        
        
    }

    void U4DScriptManager::removeItemsInList(gravity_list_t *l){
        
        size_t count = marray_size(l->array);

        //pop all items in array
        for(int i=0;i<count;i++){
            marray_pop(l->array);
        }
        
    }

    void U4DScriptManager::freeUserInputObjects(){
        
//        //free up all strings that were mem allocated
//        for(auto n:userInputElementArray){
//            gravity_string_free(vm, VALUE_AS_STRING(n));
//        }
//
//        //free up all lists that were mem allocated
//
//        gravity_list_free(vm,joystickDirectionList);
//        gravity_list_free(vm,inputPositionList);
//        gravity_list_free(vm,previousMousePositionList);
//        gravity_list_free(vm,mouseDeltaPositionList);
//        gravity_list_free(vm,arrowKeyDirectionList);
//
//        //free up map that was mem allocated
//        gravity_map_free(vm, controllerInputMessageMap);
        
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

    void U4DScriptManager::cleanup(){
        
        //gravity_compiler_free(compiler);
        gravity_vm_free(vm);
        gravity_core_free();
    }

}
