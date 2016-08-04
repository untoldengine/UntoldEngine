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
    
class U4DShaderManager{
    
private:
    
public:
    
    std::string shaders[14]={"SkyBoxShader","imageShader","spriteShader","geometricShader","multiImageShader","NormalMapping","AnimationShader","modelShader","shadowShader","worldShader","simpleShader","lightShader","debugShader","simpleFlatShader"};
    
    U4DShaderManager(){};
    
    GLuint loadShaderPair(const char *szVertexProg, const char *szFragmentProg);
    bool gltLoadShaderFile(const char *szFile, GLuint shader);
    void gltLoadShaderSrc(const char *szShaderSrc, GLuint shader);
};
    
}

#endif /* defined(__MVCTemplateV001__ShaderManager__) */

