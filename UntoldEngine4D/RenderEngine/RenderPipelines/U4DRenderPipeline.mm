//
//  U4DRenderPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderPipeline.h"
#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"
#include "U4DRenderManager.h"
#include "U4DLogger.h"
#include <iostream>
#include <fstream> //for file i/o

namespace U4DEngine {

    U4DRenderPipeline::U4DRenderPipeline(std::string uName):name(uName){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        mtlDevice=director->getMTLDevice();
        
    }
        
    U4DRenderPipeline::~U4DRenderPipeline(){
        
    }

    void U4DRenderPipeline::initPipeline(std::string uVertexShader, std::string uFragmentShader){
        
        initTargetTexture();
        initVertexDesc();
        initPassDesc();
        
        initLibrary(uVertexShader,uFragmentShader);
        initAdditionalInfo();
        
        if(buildPipeline()){
            
            U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
            renderManager->addRenderPipeline(this);
            
        }
        
    }

    std::string U4DRenderPipeline::getName(){
        
        return name;
        
    }

    void U4DRenderPipeline::initLibrary(std::string uVertexShader, std::string uFragmentShader){
        
        //init the library
        mtlLibrary=[mtlDevice newDefaultLibrary];

        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uFragmentShader.c_str()]];
        
    }

    void U4DRenderPipeline::initAdditionalInfo(){
        
        
        
    }

    id<MTLTexture> U4DRenderPipeline::getTargetTexture(){
        
        return targetTexture;
        
    }

    void U4DRenderPipeline::setInputTexture(id<MTLTexture> uInputTexture){
        inputTexture=uInputTexture;
    }

    void U4DRenderPipeline::hotReloadShaders(std::string uFilepath, std::string uVertexShader, std::string uFragmentShader){

        U4DLogger *logger=U4DLogger::sharedInstance();

        NSError *error;
        
        //read in the shader file using input stream
        std::ifstream ifs(uFilepath);

        //load the content of the shader into string
        std::string shaderContent;
        shaderContent.assign( (std::istreambuf_iterator<char>(ifs) ),
                        (std::istreambuf_iterator<char>()));

        NSString* shaderCode = [NSString stringWithUTF8String:shaderContent.c_str()];

        //create temporary library with shader content
        id<MTLLibrary> tempMTLLibrary=[mtlDevice newLibraryWithSource:shaderCode options:nil error:&error];

        //if temp library failed, then display why
        if (!tempMTLLibrary) {

            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            logger->log("Error: loading the library for hot reloading. %s",errorDesc.c_str());

        }else{

            //create temp pipeline descriptor
            MTLRenderPipelineDescriptor *tempMTLRenderPipelineDescriptor;

            //copy data from original descriptor
            tempMTLRenderPipelineDescriptor=mtlRenderPassPipelineDescriptor;

            //create temp vertex and fragment programs
            id<MTLFunction> tempVertexProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
            id<MTLFunction> tempFragmentProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:uFragmentShader.c_str()]];

             //since we already have a pointer to our pipeline descriptor, the only thing we need to update are the shader programs
             tempMTLRenderPipelineDescriptor.vertexFunction=tempVertexProgram;
             tempMTLRenderPipelineDescriptor.fragmentFunction=tempFragmentProgram;

             //create a temp rendering pipeline

             id<MTLRenderPipelineState> tempMTLRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:tempMTLRenderPipelineDescriptor error:&error];

            //check if temp pipeline was successfully created. If so, swap it with primary pipeline
            if(!tempMTLRenderPipelineState){
                
                //Pipeline failed
                std::string errorDesc= std::string([error.localizedDescription UTF8String]);
                logger->log("Error: The pipeline %s was unable to be hot-reloaded. %s",name.c_str(),errorDesc.c_str());

            }else{

                //Pipeline was successfully hot-reloaded
                mtlRenderPassPipelineDescriptor=tempMTLRenderPipelineDescriptor;
                mtlRenderPassPipelineState=tempMTLRenderPipelineState;
                vertexProgram=tempVertexProgram;
                fragmentProgram=tempFragmentProgram;
                mtlLibrary=tempMTLLibrary;
                
                logger->log("The pipeline %s was hot-reloaded",name.c_str());


            }

        }

    }

}
