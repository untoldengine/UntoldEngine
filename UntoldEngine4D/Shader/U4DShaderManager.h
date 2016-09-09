//
//  ShaderManager.h
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/12/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplateV001__U4DShaderManager__
#define __MVCTemplateV001__U4DShaderManager__

#include <iostream>
#include <string>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

// prevent heap fragmentation
#define MAX_SHADER_LENGTH   8192

namespace U4DEngine {

/**
 @brief The U4DShaderManager class is in charge of loading, compiling and attaching the shaders to the GPU. It manages all shaders loading operations.
 */
class U4DShaderManager{
    
private:
    
public:

    /**
     @brief Array containing the shader programs names
     */
    std::string shaders[12]={"SkyBoxShader","imageShader","spriteShader","geometricShader","multiImageShader","NormalMapping","AnimationShader","modelShader","phongShader","lightShader","debugShader","gouraudShader"};
    
    /**
     @brief Shader manager constructor
     */
    U4DShaderManager();
    
    /**
     @brief Shader manager destructor
     */
    ~U4DShaderManager();
    
    /**
     @brief Method which loads the pair of shaders. That is, it loads the vertex and fragment shader
     
     @param szVertexProg   name of vertex shader
     @param szFragmentProg name of fragment shader
     
     @return Returns a shader object
     */
    GLuint loadShaderPair(const char *szVertexProg, const char *szFragmentProg);
    
    /**
     @brief Method which loads the shader file
     
     @param szFile Shader file name
     @param shader shader object
     
     @return Returns true if the shader file was opened and read properly
     */
    bool gltLoadShaderFile(const char *szFile, GLuint shader);
    
    /**
     @brief Method which loads the shader source code
     
     @param szShaderSrc shader source code
     @param shader      shader object
     */
    void gltLoadShaderSrc(const char *szShaderSrc, GLuint shader);
};
    
}

#endif /* defined(__MVCTemplateV001__ShaderManager__) */

