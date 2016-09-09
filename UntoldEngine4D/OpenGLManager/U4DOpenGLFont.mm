//
//  U4DOpenGLFont.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/19/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLFont.h"
#include "U4DDirector.h"
#include "Constants.h"
#include "U4DFont.h"

namespace U4DEngine {
    
U4DOpenGLFont::U4DOpenGLFont(U4DImage* uU4DImage):U4DOpenGLImage(uU4DImage){
    u4dObject=uU4DImage; //attach the object to render
}


U4DOpenGLFont::~U4DOpenGLFont(){

}
    
void U4DOpenGLFont::updateVertexObjectBuffer(){
    
    
    glBindVertexArray(vertexObjectArray);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), &u4dObject->bodyCoordinates.verticesContainer[0]);
    
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()), sizeof(float)*2*u4dObject->bodyCoordinates.uVContainer.size(), &u4dObject->bodyCoordinates.uVContainer[0]);
    
    
}


void U4DOpenGLFont::updateImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){
    
    //clear the current buffer
    u4dObject->bodyCoordinates.verticesContainer.clear();
    u4dObject->bodyCoordinates.uVContainer.clear();
    u4dObject->bodyCoordinates.indexContainer.clear();
    
    setImageDimension(uWidth, uHeight,uAtlasWidth,uAtlasHeight);
    
}

void U4DOpenGLFont::setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){
   
    U4DDirector *director=U4DDirector::sharedInstance();
    
    float widthFontTexture=uWidth/uAtlasWidth;
    float heightFontTexture=uHeight/uAtlasHeight;
    
    float width=uWidth/director->getDisplayWidth();
    float height=uHeight/director->getDisplayHeight();
    float depth=0.0;

    
    //vertices
    U4DVector3n v1(width,height,depth);
    U4DVector3n v4(width,-height,depth);
    U4DVector3n v2(-width,-height,depth);
    U4DVector3n v3(-width,height,depth);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
    
    //texture
    U4DVector2n t4(0.0,0.0);  //top left
    U4DVector2n t1(1.0*widthFontTexture,0.0);  //top right
    U4DVector2n t3(0.0,1.0*heightFontTexture);  //bottom left
    U4DVector2n t2(1.0*widthFontTexture,1.0*heightFontTexture);  //bottom right
    
    u4dObject->bodyCoordinates.addUVDataToContainer(t1);
    u4dObject->bodyCoordinates.addUVDataToContainer(t2);
    u4dObject->bodyCoordinates.addUVDataToContainer(t3);
    u4dObject->bodyCoordinates.addUVDataToContainer(t4);
    
    U4DIndex i1(0,1,2);
    U4DIndex i2(2,3,0);
    
    //index
    u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i2);
    
}

}
