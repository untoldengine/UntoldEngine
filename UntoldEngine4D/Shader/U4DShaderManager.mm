//
//  ShaderManager.cpp
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/12/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DShaderManager.h"
#include <iostream>

namespace U4DEngine {
    
static GLubyte shaderText[MAX_SHADER_LENGTH];
    
U4DShaderManager::U4DShaderManager(){
}
    
U4DShaderManager::~U4DShaderManager(){
}

GLuint U4DShaderManager::loadShaderPair(const char *szVertexProg, const char *szFragmentProg)
{
    // Temporary Shader objects
    GLuint hVertexShader;
    GLuint hFragmentShader;
    GLuint hReturn = 0;
    GLint testVal;
	
    // Create shader objects
    hVertexShader = glCreateShader(GL_VERTEX_SHADER);
    hFragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	
    // Load them. If fail clean up and return null
    if(gltLoadShaderFile(szVertexProg, hVertexShader) == false)
    {
        glDeleteShader(hVertexShader);
        glDeleteShader(hFragmentShader);
        fprintf(stderr, "The shader at %s could not be found.\n", szVertexProg);
        return (GLuint)NULL;
    }else{
       // fprintf(stderr,"Vertex shaders loaded successfully\n");
    }
	
    if(gltLoadShaderFile(szFragmentProg, hFragmentShader) == false)
    {
        glDeleteShader(hVertexShader);
        glDeleteShader(hFragmentShader);
        fprintf(stderr,"The shader at %s  could not be found.\n", szFragmentProg);
        return (GLuint)NULL;
    }else{
       // fprintf(stderr,"Fragment shaders loaded successfully\n");
    }
    
    // Compile them
    glCompileShader(hVertexShader);
    glCompileShader(hFragmentShader);
    
    // Check for errors
    glGetShaderiv(hVertexShader, GL_COMPILE_STATUS, &testVal);
    if(testVal == GL_FALSE)
    {
        char infoLog[1024];
        glGetShaderInfoLog(hVertexShader, 1024, NULL, infoLog);
        fprintf(stderr, "The shader at %s failed to compile with the following error:\n%s\n", szVertexProg, infoLog);
        glDeleteShader(hVertexShader);
        glDeleteShader(hFragmentShader);
        return (GLuint)NULL;
    }else{
        //fprintf(stderr,"Vertex Shader compiled successfully\n");
    }
    
    glGetShaderiv(hFragmentShader, GL_COMPILE_STATUS, &testVal);
    if(testVal == GL_FALSE)
    {
        char infoLog[1024];
        glGetShaderInfoLog(hFragmentShader, 1024, NULL, infoLog);
        fprintf(stderr, "The shader at %s failed to compile with the following error:\n%s\n", szFragmentProg, infoLog);
        glDeleteShader(hVertexShader);
        glDeleteShader(hFragmentShader);
        return (GLuint)NULL;
    }else{
        //fprintf(stderr,"Fragment Shader compiled successfully\n");
    }
    
    // Link them - assuming it works...
    hReturn = glCreateProgram();
    glAttachShader(hReturn, hVertexShader);
    glAttachShader(hReturn, hFragmentShader);
    
    glLinkProgram(hReturn);
	
    // These are no longer needed
    glDeleteShader(hVertexShader);
    glDeleteShader(hFragmentShader);
    
    // Make sure link worked too
    glGetProgramiv(hReturn, GL_LINK_STATUS, &testVal);
    if(testVal == GL_FALSE)
    {
        char infoLog[1024];
        glGetProgramInfoLog(hReturn, 1024, NULL, infoLog);
        fprintf(stderr,"The programs %s and %s failed to link with the following errors:\n%s\n",
                szVertexProg, szFragmentProg, infoLog);
        glDeleteProgram(hReturn);
        return (GLuint)NULL;
    }else{
        //fprintf(stderr,"Shaders linked successfully\n");
    }
    
    return hReturn;
}

bool U4DShaderManager::gltLoadShaderFile(const char *szFile, GLuint shader)
{
    GLint shaderLength = 0;
    FILE *fp;
	
    // Open the shader file
    fp = fopen(szFile, "r");
    if(fp != NULL)
    {
        // See how long the file is
        while (fgetc(fp) != EOF)
            shaderLength++;
		
        // Allocate a block of memory to send in the shader
        //assert(shaderLength < MAX_SHADER_LENGTH);   // make me bigger!
        if(shaderLength > MAX_SHADER_LENGTH)
        {
            fclose(fp);
            return false;
        }
		
        // Go back to beginning of file
        rewind(fp);
		
        // Read the whole file in
        if (shaderText != NULL)
            fread(shaderText, 1, shaderLength, fp);
		
        // Make sure it is null terminated and close the file
        shaderText[shaderLength] = '\0';
        fclose(fp);
    }
    else
        return false;
	
    // Load the string
    gltLoadShaderSrc((const char *)shaderText, shader);
    
    return true;
}

// Load the shader from the source text
void U4DShaderManager::gltLoadShaderSrc(const char *szShaderSrc, GLuint shader)
{
    GLchar *fsStringPtr[1];
    
    fsStringPtr[0] = (GLchar *)szShaderSrc;
    glShaderSource(shader, 1, (const GLchar **)fsStringPtr, NULL);
}

}