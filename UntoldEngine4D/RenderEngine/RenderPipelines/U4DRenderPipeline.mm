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
#include "U4DLights.h"
#include "U4DLogger.h"
#include <iostream>
#include <fstream> //for file i/o

namespace U4DEngine {

    U4DRenderPipeline::U4DRenderPipeline(id <MTLDevice> uMTLDevice, std::string uName):mtlDevice(uMTLDevice),name(uName){
        
    }
        
    U4DRenderPipeline::~U4DRenderPipeline(){
        
    }

    void U4DRenderPipeline::initRenderPass(std::string uVertexShader, std::string uFragmentShader){
        
        initRenderPassTargetTexture();
        initVertexDesc();
        initRenderPassLibrary(uVertexShader,uFragmentShader);
        initRenderPassDesc();
        initRenderPassPipeline();
        initRenderPassAdditionalInfo();
        
        
    }

    std::string U4DRenderPipeline::getName(){
        
        return name;
        
    }

    void U4DRenderPipeline::initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader){
        
        //init the library
        mtlLibrary=[mtlDevice newDefaultLibrary];

        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uFragmentShader.c_str()]];
        
    }

    void U4DRenderPipeline::initRenderPassAdditionalInfo(){
        
        
        
    }

    id<MTLTexture> U4DRenderPipeline::getTargetTexture(){
        
        return targetTexture;
        
    }

    void U4DRenderPipeline::setInputTexture(id<MTLTexture> uInputTexture){
        inputTexture=uInputTexture;
    }

    void U4DRenderPipeline::hotReloadShaders(std::string uFilepath, std::string uVertexShader, std::string uFragmentShader){

        //reload the library
        U4DLogger *logger=U4DLogger::sharedInstance();

        NSError *error;
        
        std::ifstream ifs(uFilepath);

        std::string shaderContent;
        shaderContent.assign( (std::istreambuf_iterator<char>(ifs) ),
                        (std::istreambuf_iterator<char>()));

        NSString* shaderCode = [NSString stringWithUTF8String:shaderContent.c_str()];

        id<MTLLibrary> tempMTLLibrary=[mtlDevice newLibraryWithSource:shaderCode options:nil error:&error];

        if (!tempMTLLibrary) {

            //NSLog(@"error loading file %@",error.localizedDescription);
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            logger->log("Error: loading the library for hot reloading. %s",errorDesc.c_str());

        }else{

            MTLRenderPipelineDescriptor *tempMTLRenderPipelineDescriptor;

            //temporarily copy the library, shader program and descriptor until we know that the hot reload was a success

            tempMTLRenderPipelineDescriptor=mtlRenderPassPipelineDescriptor;

            id<MTLFunction> tempVertexProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
            id<MTLFunction> tempFragmentProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:uFragmentShader.c_str()]];

             //since we already have a pointer to our pipeline descriptor, the only thing we need to update are the shader programs
             tempMTLRenderPipelineDescriptor.vertexFunction=tempVertexProgram;
             tempMTLRenderPipelineDescriptor.fragmentFunction=tempFragmentProgram;

             //create the rendering pipeline object

             id<MTLRenderPipelineState> tempMTLRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:tempMTLRenderPipelineDescriptor error:&error];

            if(!tempMTLRenderPipelineState){

                //NSLog(@"The pipeline was unable to be created: %@",error.localizedDescription);

                std::string errorDesc= std::string([error.localizedDescription UTF8String]);
                logger->log("Error: The pipeline was unable to be created. %s",errorDesc.c_str());

            }else{

                logger->log("The pipeline was updated");

                mtlRenderPassPipelineDescriptor=tempMTLRenderPipelineDescriptor;
                mtlRenderPassPipelineState=tempMTLRenderPipelineState;
                vertexProgram=tempVertexProgram;
                fragmentProgram=tempFragmentProgram;
                mtlLibrary=tempMTLLibrary;

            }

        }

    }

}
