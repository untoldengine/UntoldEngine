//
//  U4DOpenGLSprite.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLSprite.h"
#include "U4DDirector.h"
#include "U4DSprite.h"

namespace U4DEngine {
    
void U4DOpenGLSprite::setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){
    
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