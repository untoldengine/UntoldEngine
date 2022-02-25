//
//  U4DScriptManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptManager_hpp
#define U4DScriptManager_hpp

#include <stdio.h>
#include "gravity_compiler.h"
#include "gravity_core.h"
#include "gravity_vm.h"
#include "gravity_macros.h"
#include "gravity_vmmacros.h"
#include "gravity_opcodes.h"
#include "gravity_utils.h"
#include "gravity_hash.h"
#include "gravity_delegate.h"
#include <iostream>
#include <list>
#include <string.h>
#include "U4DVector3n.h"

namespace U4DEngine {

    enum UserInputListEnum{
            inputElementType,
            inputElementAction,
            joystickDirection,
            inputPosition,
            previousMousePosition,
            mouseDeltaPosition,
            joystickChangeDirection,
            mouseChangeDirection,
            arrowKeyDirection,
            elementUIName,
            dataValue
        };

    class U4DScriptManager {
        
    private:
    
        static U4DScriptManager *instance;
        
        gravity_list_t *userInputList;
        
        
    protected:
        
        U4DScriptManager();
        
        ~U4DScriptManager();
        
    public:
        
        //gravity_closure_t *closure;
        gravity_compiler_t *compiler;
        gravity_vm *vm;
        gravity_delegate_t delegate;
        
        static U4DScriptManager *sharedInstance();
        
        static void freeObjects(gravity_vm *vm, gravity_object_t *obj);
        static void registerClasses (gravity_vm *vm);
        static void reportError(gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata);
        bool loadScript(std::string uScriptPath);
        bool init();
        void cleanup();
        void loadGameConfigs();
        
        static const char *loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static);
        
        void awakeClosure();
        void initClosure();
        void preUpdateClosure(double dt);
        void updateClosure(double dt);
        void update(int uScriptID, double dt);
        void userInputClosure(void *uData);
        void deInitClosure();
        
        void removeItemsInList(gravity_list_t *l);
        void freeUserInputObjects();
        
        //bridge
        
        static bool worldCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool loadModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool removeModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //vector3n
        static bool vector3nNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nAdd(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nSub(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nMul(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nDiv(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
            
        static bool vector3nMagnitude(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nNormalize(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
            
        static bool vector3nDot(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nCross(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool vector3nAngle(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
            
        static bool vector3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool xGet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool xSet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool yGet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool ySet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool zGet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool zSet(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static void vector3nFree(gravity_vm *vm, gravity_object_t *obj);
        
        //U4DModel
        static bool modelCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelDestroy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelSetPipeline(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelGetAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelGetAbsoluteOrientation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelGetViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelSetViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool modelSetEntityForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool modelGetDimensions(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        
        static bool modelLoadAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        void modelFree(gravity_vm *vm, gravity_object_t *obj);
        
        
        
        //U4DAnimation
        static bool animationCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationStop(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        void animationFree (gravity_vm *vm, gravity_object_t *obj);
        
        
        //Animation manager
        static bool animationManagerCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerSetAnimToPlay(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool animationManagerRemoveCurrentPlayAnim(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        void animationManagerFree (gravity_vm *vm, gravity_object_t *obj);
        
        //Dynamic Actions
        static bool dynamicActionCreate(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionEnableKinetic(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionEnableCollision(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionAddForce(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetAwake(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionGetVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetCollisionFilterCategory(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetCollisionFilterMask(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionAddMoment(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetIsCollisionSensor(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetCollidingTag(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionGetMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionGetModelHasCollided(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionGetCollisionListTags(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionInitMass(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionInitAsPlatform(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionResumeCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionPauseCollisionBehavior(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool dynamicActionSetAngularVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionSetDragCoefficient(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool dynamicActionInitInertiaTensorType(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        void dynamicActionFree (gravity_vm *vm, gravity_object_t *obj);
        
        //logger
        static bool loggerNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool loggerLog(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static void loggerFree (gravity_vm *vm, gravity_object_t *obj);
        static void cameraFree (gravity_vm *vm, gravity_object_t *obj);
        
        //camera
        static bool cameraNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool cameraTranslateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool cameraTranslateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool cameraRotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool cameraRotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setCameraAsThirdPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool setCameraAsFirstPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool setCameraAsBasicFollow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //AI Steering
        static bool aiSeekNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool aiSeekGetSteering(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool aiSeekSetMaxSpeed(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static void aiSeekFree (gravity_vm *vm, gravity_object_t *obj);
        
        static bool aiArriveNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool aiArriveGetSteering(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool aiArriveSetMaxSpeed(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static void aiArriveFree (gravity_vm *vm, gravity_object_t *obj);
        
        //control
        static bool anchorMouse(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool pauseScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool playScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
    };

}

#endif /* U4DScriptManager_hpp */
