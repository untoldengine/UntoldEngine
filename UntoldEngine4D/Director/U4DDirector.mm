//
//  God.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DDirector.h"
#include "U4DScheduler.h"

#include "U4DWorld.h"
#include "U4DScene.h"
#include "U4DGameModelInterface.h"
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "Constants.h"


namespace U4DEngine {
    
    U4DDirector::U4DDirector():accumulator(0.0),displayWidth(0.0),displayHeight(0.0){
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


    void U4DDirector::draw(){
        
        //draw the view
        scene->draw();
        
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

    void U4DDirector::loadShaders(){
       
        //initialize the shaders available
        
        int arrayLength=sizeof(shaderManager.shaders)/sizeof(*shaderManager.shaders);
        
        for (int i=0; i<arrayLength; i++) {
            
            std::string vertexShaderString=shaderManager.shaders[i]+".vp";
            std::string fragmentShaderString=shaderManager.shaders[i]+".fp";
            
            const char *vertexShaderName=vertexShaderString.c_str();
            const char *fragmentShaderName=fragmentShaderString.c_str();
            
            GLuint shaderID=shaderManager.loadShaderPair(vertexShaderName, fragmentShaderName);
            
            addShaderProgram(shaderID);

        }
            
    }

    void U4DDirector::init(){
        
    }



    void U4DDirector::setScene(U4DScene *uScene){
        
        //initialize the Universe
        scene=uScene;
        
    }

    void U4DDirector::addShaderProgram(GLuint uShaderValue){
        
        shaderProgram.push_back(uShaderValue);
    }


    GLuint U4DDirector::getShaderProgram(std::string uShader){

        int shaderIndex=0;
        
        int arrayLength=sizeof(shaderManager.shaders)/sizeof(*shaderManager.shaders);
        
        const char *uShaderName=uShader.c_str();
        
        for (int i=0; i<arrayLength; i++) {

            if (uShaderName==shaderManager.shaders[i]) {
                
                shaderIndex=i;
            }
        }
        
        return shaderProgram.at(shaderIndex);
    }

    void U4DDirector::setDisplayWidthHeight(float uWidth,float uHeight){
        
        displayHeight=uHeight;
        displayWidth=uWidth;
    }

    float U4DDirector::getDisplayHeight(){
        
        return displayHeight*2.0;

    }

    float U4DDirector::getDisplayWidth(){
        
        return displayWidth*2.0;
        
    }



    U4DVector2n U4DDirector::pointToOpenGL(float xPoint,float yPoint){
        
        xPoint=(xPoint-displayWidth/2)/(displayWidth/2);
        yPoint=(displayHeight/2-yPoint)/(displayHeight/2);
        
        U4DVector2n point(xPoint,yPoint);
        
        return point;
        
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

}
