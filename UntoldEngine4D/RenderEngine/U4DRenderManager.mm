//
//  RenderManager.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include "U4DRenderManager.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include <simd/simd.h>
#include "lodepng.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DRenderManager::U4DRenderManager():eligibleToRender(false){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        mtlDevice=director->getMTLDevice();
        
        
    }
    
    U4DRenderManager::~U4DRenderManager(){
        
    }
    
    void U4DRenderManager::loadRenderingInformation(){
        
        initMTLRenderLibrary();
        initMTLRenderPipeline();
        
        if(loadMTLBuffer()){
            
            loadMTLTexture();
            
            //loads additional information such as normal map, bones, etc if it exists.
            loadMTLAdditionalInformation();
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No rendering data was found for the object. This object will not be rendered by the engine");
            
        }
        
        
    }
    
    void U4DRenderManager::clearRawImageData(){
        
        imageWidth=0.0;
        imageHeight=0.0;
        rawImageData.clear();
    }
    
    void U4DRenderManager::createTextureObject(){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the texture object
        textureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        //Copy the raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [textureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
        
    }
    
    void U4DRenderManager::createSamplerObject(){
        
        //Create a sampler descriptor
        
        MTLSamplerDescriptor *samplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        //Set the filtering and addressing settings
        samplerDescriptor.minFilter=MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter=MTLSamplerMinMagFilterLinear;
        
        //set the addressing mode for the S component
        samplerDescriptor.sAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //set the addressing mode for the T component
        samplerDescriptor.tAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //Create the sampler state object
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:samplerDescriptor];
        
    }
    
    void U4DRenderManager::createNormalMapTextureObject(){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *normalMapTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the normal texture object
        normalMapTextureObject=[mtlDevice newTextureWithDescriptor:normalMapTextureDescriptor];
        
        //Copy the normal map raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [normalMapTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
        
    }
    
    void U4DRenderManager::createNormalMapSamplerObject(){
        
        //Create a sampler descriptor
        
        MTLSamplerDescriptor *samplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        //Set the filtering and addressing settings
        samplerDescriptor.minFilter=MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter=MTLSamplerMinMagFilterLinear;
        
        //set the addressing mode for the S component
        samplerDescriptor.sAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //set the addressing mode for the T component
        samplerDescriptor.tAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //Create the sampler state object
        
        samplerNormalMapStateObject=[mtlDevice newSamplerStateWithDescriptor:samplerDescriptor];
        
    }
    
    void U4DRenderManager::decodeImage(std::string uTexture){
        
        imageWidth=0.0;
        imageHeight=0.0;
        
        // Load file and decode image.
        const char * textureImage = uTexture.c_str();
        
        unsigned error = lodepng::decode(rawImageData, imageWidth, imageHeight,textureImage);
        
        //if there's an error, display it
        if(error){
            std::cout << "decoder error " << error << ": " <<uTexture<<" file is "<< lodepng_error_text(error) << std::endl;
        }else{
            
            //Flip and invert the image
            unsigned char* imagePtr=&rawImageData[0];
            
            int halfTheHeightInPixels=imageHeight/2;
            int heightInPixels=imageHeight;
            
            
            //Assume RGBA for 4 components per pixel
            int numColorComponents=4;
            
            //Assuming each color component is an unsigned char
            int widthInChars=imageWidth*numColorComponents;
            
            unsigned char *top=NULL;
            unsigned char *bottom=NULL;
            unsigned char temp=0;
            
            for( int h = 0; h < halfTheHeightInPixels; ++h )
            {
                top = imagePtr + h * widthInChars;
                bottom = imagePtr + (heightInPixels - h - 1) * widthInChars;
                
                for( int w = 0; w < widthInChars; ++w )
                {
                    // Swap the chars around.
                    temp = *top;
                    *top = *bottom;
                    *bottom = temp;
                    
                    ++top;
                    ++bottom;
                }
            }
        }
        
    }
    
    std::vector<unsigned char> U4DRenderManager::decodeImage(const char *uTexture){
        
        // Load file and decode image.
        std::vector<unsigned char> image;
        unsigned int width, height;
        
        unsigned error;
        
        error = lodepng::decode(image, width, height,uTexture);
        
        //if there's an error, display it
        if(error){
            std::cout << "decoder error " << error << ": " << lodepng_error_text(error) << std::endl;
        }else{
            
            
            //Flip and invert the image
            unsigned char* imagePtr=&image[0];
            
            int halfTheHeightInPixels=height/2;
            int heightInPixels=height;
            
            //Assume RGBA for 4 components per pixel
            int numColorComponents=4;
            
            //Assuming each color component is an unsigned char
            int widthInChars=width*numColorComponents;
            
            unsigned char *top=NULL;
            unsigned char *bottom=NULL;
            unsigned char temp=0;
            
            for( int h = 0; h < halfTheHeightInPixels; ++h )
            {
                top = imagePtr + h * widthInChars;
                bottom = imagePtr + (heightInPixels - h - 1) * widthInChars;
                
                for( int w = 0; w < widthInChars; ++w )
                {
                    // Swap the chars around.
                    temp = *top;
                    *top = *bottom;
                    *bottom = temp;
                    
                    ++top;
                    ++bottom;
                }
            }
            
            
        }
        
        imageWidth=width;
        imageHeight=height;
        
        
        return image;
        
    }
    
    void U4DRenderManager::addTexturesToSkyboxContainer(const char* uTextures){
        
        skyboxTexturesContainer.push_back(uTextures);
    }
    
    std::vector<const char*> U4DRenderManager::getSkyboxTexturesContainer(){
        
        return skyboxTexturesContainer;
        
    }
    
    
    matrix_float4x4 U4DRenderManager::convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix){
        
        // 4x4 matrix - column major. X vector is 0, 1, 2, etc.
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        matrix_float4x4 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        m.columns[0][3]=uMatrix.matrixData[3];
        
        m.columns[1][0]=uMatrix.matrixData[4];
        m.columns[1][1]=uMatrix.matrixData[5];
        m.columns[1][2]=uMatrix.matrixData[6];
        m.columns[1][3]=uMatrix.matrixData[7];
        
        m.columns[2][0]=uMatrix.matrixData[8];
        m.columns[2][1]=uMatrix.matrixData[9];
        m.columns[2][2]=uMatrix.matrixData[10];
        m.columns[2][3]=uMatrix.matrixData[11];
        
        m.columns[3][0]=uMatrix.matrixData[12];
        m.columns[3][1]=uMatrix.matrixData[13];
        m.columns[3][2]=uMatrix.matrixData[14];
        m.columns[3][3]=uMatrix.matrixData[15];
        
        return m;
        
    }
    
    matrix_float3x3 U4DRenderManager::convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix){
        
        //	0	3	6
        //	1	4	7
        //	2	5	8
        
        matrix_float3x3 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        
        m.columns[1][0]=uMatrix.matrixData[3];
        m.columns[1][1]=uMatrix.matrixData[4];
        m.columns[1][2]=uMatrix.matrixData[5];
        
        m.columns[2][0]=uMatrix.matrixData[6];
        m.columns[2][1]=uMatrix.matrixData[7];
        m.columns[2][2]=uMatrix.matrixData[8];
        
        return m;
        
    }
    
    vector_float4 U4DRenderManager::convertToSIMD(U4DEngine::U4DVector4n &uVector){
        
        vector_float4 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        v.z=uVector.z;
        v.w=uVector.w;
        
        return v;
    }

}

