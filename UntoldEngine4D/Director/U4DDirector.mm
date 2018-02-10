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
#include "U4DGameModelInterface.h"
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DWorld.h"


namespace U4DEngine {
    
    U4DDirector::U4DDirector():accumulator(0.0),displayWidth(0.0),displayHeight(0.0),polycount(3000),shadowBiasDepth(0.005){
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
    
    void U4DDirector::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        //render
        scene->render(uRenderEncoder);
    }
    
    void U4DDirector::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
       //render shadows
        scene->renderShadow(uRenderShadowEncoder, uShadowTexture);
    }

    void U4DDirector::update(double dt){
        
        //set up the time step
        
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        
        float frameTime=dt;
        
        if (frameTime>0.25) {
            
            frameTime=0.25;
            
        }
        
        accumulator+=frameTime;
        
        while (accumulator>=timeStep) {
            
            //update state and physics engine
            scene->update(timeStep);
            
            //update the scheduler
            scheduler->tick(timeStep);
            
            accumulator-=timeStep;
            
        }
        
        
        
    }

    void U4DDirector::determineVisibility(){
        
        scene->determineVisibility();
        
    }
    
    void U4DDirector::init(){
        
    }



    void U4DDirector::setScene(U4DScene *uScene){
        
        //initialize the Universe
        scene=uScene;
        
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
    
    void U4DDirector::setShadowBiasDepth(float uValue){
        
        shadowBiasDepth=uValue;
    }
    
    float U4DDirector::getShadowBiasDepth(){
        
        return shadowBiasDepth;
    }

    void U4DDirector::touchBegan(const U4DTouches &touches){
        
        scene->touchBegan(touches);
        
    }

    void U4DDirector::touchEnded(const U4DTouches &touches){
        
        scene->touchEnded(touches);
    }

    void U4DDirector::touchMoved(const U4DTouches &touches){
        
        scene->touchMoved(touches);
    }
    
    void U4DDirector::padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){
        
        scene->padPressBegan(uGamePadElement, uGamePadAction);
        
    }
    
    void U4DDirector::padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){
        
        scene->padPressEnded(uGamePadElement, uGamePadAction);
    }
    
    void U4DDirector::padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){
        
        scene->padThumbStickMoved(uGamePadElement, uGamePadAction, uPadAxis);
        
    }
    
    void U4DDirector::setWorld(U4DWorld *uWorld){
        
        world=uWorld;
        
    }
    
    U4DEntity *U4DDirector::searchChild(std::string uName){
        
        return world->searchChild(uName);
        
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
        
        float fovToRad=fov*(M_PI/180);
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

}
