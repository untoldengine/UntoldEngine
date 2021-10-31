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
#include <string.h>
#include "U4DScriptBridge.h"

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
        
        gravity_list_t *joystickDirectionList;
        gravity_list_t *inputPositionList;
        gravity_list_t *previousMousePositionList;
        gravity_list_t *mouseDeltaPositionList;
        gravity_list_t *arrowKeyDirectionList;
        gravity_map_t *controllerInputMessageMap;
        
        gravity_value_t userInputElementArray[11];
        
    protected:
        
        U4DScriptManager();
        
        ~U4DScriptManager();
        
    public:
        
        //gravity_closure_t *closure;
        gravity_compiler_t *compiler;
        gravity_vm *vm;
        gravity_delegate_t delegate;
        
        static U4DScriptManager *sharedInstance();
        
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
        
        //matrix
        static bool matrix3nNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool matrix3nShow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool matrix3nTransformVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static void matrix3nFree(gravity_vm *vm, gravity_object_t *obj);
        
        //logger
        static bool loggerNew(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool loggerLog(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static void loggerFree (gravity_vm *vm, gravity_object_t *obj);
        
        //bridge
        static bool bridgeInstance(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool loadModel(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool addChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool removeChild(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        

        //transformation
        static bool translateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool translateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool rotateTo(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool rotateBy(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool getAbsolutePosition(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool getAbsoluteOrientation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool getViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setViewInDirection(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool setEntityForwardVector(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //physics
        static bool initPhysics(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool deinitPhysics(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool applyVelocity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setGravity(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setCollisionFilterCategory(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setCollisionFilterMask(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setIsCollisionSensor(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setCollidingTag(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool getModelHasCollided(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool getCollisionListTags(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //animation
        static bool initAnimations(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool deinitAnimations(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool playAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool stopAnimation(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setEntityToArmatureBoneSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        static bool setEntityToAnimationBoneSpace(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //AI Steering
        static bool seek(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool arrive(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool pursuit(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //camera
        static bool setCameraAsThirdPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool setCameraAsFirstPerson(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool setCameraAsBasicFollow(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        //control
        static bool anchorMouse(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool pauseScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        static bool playScene(gravity_vm *vm, gravity_value_t *args, uint16_t nargs, uint32_t rindex);
        
        void awakeClosure();
        void initClosure();
        void preUpdateClosure(double dt);
        void updateClosure(double dt);
        void userInputClosure(void *uData);
        void deInitClosure();
        
        void removeItemsInList(gravity_list_t *l);
        void freeUserInputObjects();
        
        static void freeObjects(gravity_vm *vm, gravity_object_t *obj);
        static void registerClasses (gravity_vm *vm);
        static void reportError(gravity_vm *vm, error_type_t error_type, const char *message, error_desc_t error_desc, void *xdata);
        
        static const char *loadFileCallback (const char *path, size_t *size, uint32_t *fileid, void *xdata, bool *is_static);
        bool loadScript(std::string uScriptPath);
        bool init();
        void cleanup();
        void loadGameConfigs();
        
    };

}

#endif /* U4DScriptManager_hpp */
