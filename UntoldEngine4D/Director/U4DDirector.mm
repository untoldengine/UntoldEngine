//
//  God.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DDirector.h"
#include "U4DScheduler.h"

#include "U4DWorld.h"
#include "U4DScene.h"
#include "U4DGameLogicInterface.h"
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DWorld.h"
#include "U4DSceneStateManager.h"

namespace U4DEngine {
    
U4DDirector::U4DDirector():accumulator(0.0),displayWidth(0.0),displayHeight(0.0),polycount(3000),shadowBiasDepth(0.005),gamePadControllerPresent(false),modelsWithinFrustum(false),screenScaleFactor(2.0),fps(0.0),fpsAccumulator(0.0),scriptCompiledSuccessfully(false),scriptRunTimeError(false),newEntityId(0){
    }
    
    U4DDirector::~U4DDirector(){
    
    }
    
    U4DDirector::U4DDirector(const U4DDirector& value){
    
    }
    
    U4DDirector& U4DDirector::operator=(const U4DDirector& value){
        
        return *this;
    
    };

    
    U4DDirector* U4DDirector::instance=0;

    U4DDirector* U4DDirector::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DDirector();
        }
        
        return instance;
    }
    
    int U4DDirector::getNewEntityId(){
        
        //increase coutn
        newEntityId++;
        
        return newEntityId;
    }

    void U4DDirector::setDisplayWidthHeight(float uWidth,float uHeight){
        
        displayHeight=uHeight;
        displayWidth=uWidth;
    }

    float U4DDirector::getDisplayHeight(){
        
        return displayHeight;

    }

    float U4DDirector::getDisplayWidth(){
        
        return displayWidth;
        
    }

    void U4DDirector::setPolycount(int uValue){
        polycount=uValue;
    }
    
    int U4DDirector::getPolycount(){
        return polycount;
    }
    
    void U4DDirector::setModelsWithinFrustum(bool uValue){
        
        modelsWithinFrustum=uValue;
        
    }
    
    bool U4DDirector::getModelsWithinFrustum(){
        
        return modelsWithinFrustum;
    }
    
    void U4DDirector::setShadowBiasDepth(float uValue){
        
        shadowBiasDepth=uValue;
    }
    
    float U4DDirector::getShadowBiasDepth(){
        
        return shadowBiasDepth;
    }
    
    
    void U4DDirector::setMTLDevice(id <MTLDevice> uMTLDevice){
        
        mtlDevice=uMTLDevice;
    }
    
    id <MTLDevice> U4DDirector::getMTLDevice(){
        
        return mtlDevice;
        
    }
    
    void U4DDirector::setAspect(float uAspect){
        
        aspect=uAspect;
    }
    
    float U4DDirector::getAspect(){
        
        return aspect;
    }
    
    void U4DDirector::setMTLView(MTKView * uMTLView){
        
        mtlView=uMTLView;
    }
    
    MTKView *U4DDirector::getMTLView(){
        
        return mtlView;
    }
    
    void U4DDirector::setDeviceOSType(DEVICEOSTYPE &uDeviceOSType){
        
        deviceOSType=uDeviceOSType;
    }
    
    DEVICEOSTYPE U4DDirector::getDeviceOSType(){
        
        return deviceOSType;
    }
    
    void U4DDirector::setGamePadControllerPresent(bool uValue){
        
        gamePadControllerPresent=uValue;
    }
    
    bool U4DDirector::getGamePadControllerPresent(){
        
        return gamePadControllerPresent;
    }
    
    void U4DDirector::setScreenScaleFactor(float uScreenScaleFactor){
        if(uScreenScaleFactor==0.0){
            screenScaleFactor=2.0;
        }else{
            screenScaleFactor=uScreenScaleFactor;
        }
        
    }
    
    float U4DDirector::getScreenScaleFactor(){
        return screenScaleFactor;
    }
    
    void U4DDirector::setPerspectiveSpace(U4DMatrix4n &uSpace){
        
        perspectiveSpace=uSpace;
        
    }
    
    void U4DDirector::setOrthographicSpace(U4DMatrix4n &uSpace){
        
        orthographicSpace=uSpace;
    }
    
    void U4DDirector::setOrthographicShadowSpace(U4DMatrix4n &uSpace){
        
        orthographicShadowSpace=uSpace;
    }
    
    U4DEngine::U4DMatrix4n U4DDirector::getPerspectiveSpace(){
        
        return perspectiveSpace;
    }
    
    U4DEngine::U4DMatrix4n U4DDirector::getOrthographicSpace(){
        
        return orthographicSpace;
        
    }
    
    U4DEngine::U4DMatrix4n U4DDirector::getOrthographicShadowSpace(){
        
        return orthographicShadowSpace;
    }
    
    U4DMatrix4n U4DDirector::computePerspectiveSpace(float fov, float aspect, float near, float far){
        
        U4DEngine::U4DMatrix4n m;
        
        setAspect(aspect);
        
        float fovToRad=fov*(M_PI/180.0);
        float yscale = 1.0f / tanf(fovToRad * 0.5f); // 1 / tan == cot
        float xscale = yscale / aspect;
        float q = far / (far - near);
        
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        
        m.matrixData[0]=xscale;
        m.matrixData[4]=0.0f;
        m.matrixData[8]=0.0f;
        m.matrixData[12]=0.0f;
        
        m.matrixData[1]=0.0f;
        m.matrixData[5]=yscale;
        m.matrixData[9]=0.0f;
        m.matrixData[13]=0.0f;
        
        m.matrixData[2]=0.0f;
        m.matrixData[6]=0.0f;
        m.matrixData[10]=q;
        m.matrixData[14]=q*-near;
        
        m.matrixData[3]=0.0f;
        m.matrixData[7]=0.0f;
        m.matrixData[11]=1.0f;
        m.matrixData[15]=0.0f;
        
        return m;
        
    }
    U4DMatrix4n U4DDirector::computeOrthographicShadowSpace(float left, float right, float bottom, float top, float near, float far){
        
        U4DEngine::U4DMatrix4n m;
        
        float r_l = 2.0/(right - left);
        float t_b = 2.0/(top - bottom);
        float f_n = -1.0/(far - near);
        float tx = (right + left) / (right - left);
        float ty = (top + bottom) / (top - bottom);
        float tz = (near) / (far - near);
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        
        m.matrixData[0]=r_l;
        m.matrixData[4]=0.0f;
        m.matrixData[8]=0.0f;
        m.matrixData[12]=-tx;
        
        m.matrixData[1]=0.0f;
        m.matrixData[5]=t_b;
        m.matrixData[9]=0.0f;
        m.matrixData[13]=-ty;
        
        m.matrixData[2]=0.0f;
        m.matrixData[6]=0.0f;
        m.matrixData[10]=f_n;
        m.matrixData[14]=-tz;
        
        m.matrixData[3]=0.0f;
        m.matrixData[7]=0.0f;
        m.matrixData[11]=0.0f;
        m.matrixData[15]=1.0f;
        
        return m;
        
    }
    
    U4DMatrix4n U4DDirector::computeOrthographicSpace(float left, float right, float bottom, float top, float near, float far){
        
        
        U4DEngine::U4DMatrix4n m;
        
        float r_l = 2.0/(right - left);
        float t_b = 2.0/(top - bottom);
        float f_n = -2.0/(far - near);
        float tx = (right + left) / (right - left);
        float ty = (top + bottom) / (top - bottom);
        float tz = (far + near) / (far - near);
        
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        
        m.matrixData[0]=r_l;
        m.matrixData[4]=0.0f;
        m.matrixData[8]=0.0f;
        m.matrixData[12]=-tx;
        
        m.matrixData[1]=0.0f;
        m.matrixData[5]=t_b;
        m.matrixData[9]=0.0f;
        m.matrixData[13]=-ty;
        
        m.matrixData[2]=0.0f;
        m.matrixData[6]=0.0f;
        m.matrixData[10]=f_n;
        m.matrixData[14]=-tz;
        
        m.matrixData[3]=0.0f;
        m.matrixData[7]=0.0f;
        m.matrixData[11]=0.0f;
        m.matrixData[15]=1.0f;
        
        return m;
        
    }

    void U4DDirector::setFPS(float uFPS){
        
        //smooth out the value by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.2;
        
        fpsAccumulator=fpsAccumulator*biasMotionAccumulator+uFPS*(1.0-biasMotionAccumulator);
        
        fps=fpsAccumulator;
        
    }
        
    float U4DDirector::getFPS(){
        return fps;
    }

    void U4DDirector::setScriptCompiledSuccessfully(bool uValue){
        scriptCompiledSuccessfully=uValue;
    }

    bool U4DDirector::getScriptCompiledSuccessfully(){
        return scriptCompiledSuccessfully;
    }

    void U4DDirector::setScriptRunTimeError(bool uValue){
        scriptRunTimeError=uValue;
    }

    bool U4DDirector::getScriptRunTimeError(){
        return scriptRunTimeError;
    }

}
