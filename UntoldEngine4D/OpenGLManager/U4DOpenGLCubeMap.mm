//
//  U4DOpenGLCubeMap.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLCubeMap.h"
#include "U4DDirector.h"
#include "U4DSkyBox.h"
#include "lodepng.h"

namespace U4DEngine {
    

U4DOpenGLCubeMap::U4DOpenGLCubeMap(U4DSkyBox *uU4DSkyBox){
    
    u4dObject=uU4DSkyBox;
    
}


U4DOpenGLCubeMap::~U4DOpenGLCubeMap(){

}
    
U4DDualQuaternion U4DOpenGLCubeMap::getEntitySpace(){
    
  return u4dObject->getAbsoluteSpace();
}
void U4DOpenGLCubeMap::loadVertexObjectBuffer(){
    
    
    //init OPENGLBUFFERS
    glGenVertexArrays(1,&vertexObjectArray);
    glBindVertexArray(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), &u4dObject->bodyCoordinates.verticesContainer[0]);
    
    
    //load the index into index buffer
    
    GLuint elementBuffer;
    
    glGenBuffers(1, &elementBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size(), &u4dObject->bodyCoordinates.indexContainer[0], GL_STATIC_DRAW);
}

void U4DOpenGLCubeMap::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");

    //position vertex
    
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);
    
}

void U4DOpenGLCubeMap::loadTextureObjectBuffer(){
  
    //load the texture
    glActiveTexture(GL_TEXTURE2);
    glGenTextures(1, &textureID[2]);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureID[2]);
    
    
    // Cull backs of polygons
    //glCullFace(GL_BACK);
    //glFrontFace(GL_CCW);
    //glEnable(GL_DEPTH_TEST);
    //glEnable(GL_TEXTURE_CUBE_MAP);
    
    // Set up texture maps
    
    std::vector<unsigned char> image;
    
    for (int i=0; i<cubeMapTextures.size(); i++) {
        
        
       image=loadCubeMapPNG(cubeMapTextures.at(i));
        
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        //glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        glTexImage2D(cubeMap[i], 0, GL_RGBA, imageWidth, imageHeight, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, &image[0]);
        
        image.clear();
    }
    
   // glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
    
    
}

void U4DOpenGLCubeMap::drawElements(){
    
   //glDepthFunc(GL_LEQUAL);
    
  glDrawElements(GL_TRIANGLES,3*u4dObject->bodyCoordinates.indexContainer.size(),GL_UNSIGNED_INT,(void*)0);

   //glDepthFunc(GL_LESS);
}

void U4DOpenGLCubeMap::activateTexturesUniforms(){

    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureID[2]);
    glUniform1i(textureUniformLocations.diffuseTextureUniformLocation, 2);
    
    
}

void U4DOpenGLCubeMap::setCubeMapDimension(float uSize){
    
 
    float size=uSize/2;
    
    //side1
    
   
    U4DVector3n v1(-size,-size,size);
    U4DVector3n v2(-size,size,size);
    U4DVector3n v3(size,size,size);
    U4DVector3n v4(size,-size,size);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
    
    
    //side2
    
 
    U4DVector3n v5(size,-size,-size);
    U4DVector3n v6(size,size,-size);
    U4DVector3n v7(-size,size,-size);
    U4DVector3n v8(-size,-size,-size);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v5);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v6);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v7);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v8);

    
    //side3
    
    U4DVector3n v9(-size,-size,-size);
    U4DVector3n v10(-size,size,-size);
    U4DVector3n v11(-size,size,size);
    U4DVector3n v12(-size,-size,size);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v9);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v10);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v11);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v12);
    
    
    //side4
    
    U4DVector3n v13(size,-size,size);
    U4DVector3n v14(size,size,size);
    U4DVector3n v15(size,size,-size);
    U4DVector3n v16(size,-size,-size);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v13);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v14);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v15);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v16);
    
    
    //side5
    
    U4DVector3n v17(-size,size,size);
    U4DVector3n v18(-size,size,-size);
    U4DVector3n v19(size,size,-size);
    U4DVector3n v20(size,size,size);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v17);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v18);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v19);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v20);
    
    
    //side6
    
    U4DVector3n v21(-size,-size,-size);
    U4DVector3n v22(-size,-size,size);
    U4DVector3n v23(size,-size,size);
    U4DVector3n v24(size,-size,-size);
    
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v21);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v22);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v23);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v24);
    
    
    U4DIndex i1(0, 1, 2);
    U4DIndex i2(2, 3, 0);
    U4DIndex i3(4, 5, 6);
    U4DIndex i4(6, 7, 4);
    
    U4DIndex i5(8, 9, 10);
    U4DIndex i6(10, 11, 8);
    U4DIndex i7(12, 13, 14);
    U4DIndex i8(14, 15, 12);
    
    U4DIndex i9(16, 17, 18);
    U4DIndex i10(18, 19, 16);
    U4DIndex i11(20, 21, 22);
    U4DIndex i12(22, 23, 20);
    
    
    u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i2);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i3);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i4);

    u4dObject->bodyCoordinates.addIndexDataToContainer(i5);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i6);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i7);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i8);

    u4dObject->bodyCoordinates.addIndexDataToContainer(i9);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i10);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i11);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i12);
    
    
}

std::vector<unsigned char> U4DOpenGLCubeMap::loadCubeMapPNG(const char *uTexture){
    
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

}
