//
//  U4DFont.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DFont.h"
#include "U4DDirector.h"
#include "U4DOpenGLFont.h"
#include "U4DFontLoader.h"

namespace U4DEngine {
    
U4DFont::U4DFont(U4DFontLoader* uFontLoader){
    
    openGlManager=new U4DOpenGLFont(this);
    openGlManager->setShader("spriteShader");
    
    //set the offset for the sprite
    std::vector<float> data={0.0};
    
    addCustomUniform("offset", data);
    
    fontLoader=uFontLoader;
   
    setFont();
    
};

void U4DFont::setFont(){
    
    const char * fontAtlasImage = fontLoader->fontAtlasImage.c_str();
    openGlManager->setDiffuseTexture(fontAtlasImage); 
    
    openGlManager->setImageDimension(0,0,fontLoader->fontAtlasWidth,fontLoader->fontAtlasHeight);
    
    openGlManager->loadRenderingInformation();
    
}

void U4DFont::setText(const char* uText){
    
    text=uText;
    textContainer.clear(); //clear the text container
    
    //break down the text
    for (int i=0; i<strlen(text); i++) {
        
        for (int j=0; j<fontLoader->fontData.size(); j++) {
            
            if (text[i]==*fontLoader->fontData[j].letter) {
                
                //copy the chars into the textContainer
                TextData textData;
                
                textData.x=fontLoader->fontData[j].x/fontLoader->fontAtlasWidth;
                textData.y=fontLoader->fontData[j].y/fontLoader->fontAtlasHeight;
                textData.width=fontLoader->fontData[j].width;
                textData.height=fontLoader->fontData[j].height;
                
                textData.xOffset=2*fontLoader->fontData[j].xoffset;
                textData.yOffset=fontLoader->fontData[j].yoffset;
                textData.xAdvance=2*fontLoader->fontData[j].xadvance;
                
                textData.letter=fontLoader->fontData[j].letter;
                
                textContainer.push_back(textData);
                
            }
        }
        
    }
    
}

void U4DFont::draw(){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    float lastTextYOffset=0.0;
    float currentTextYOffset=0.0;
    float lastTextXAdvance=0.0;
    
    U4DVector3n initPosition=getLocalPosition();
    
    translateTo(initPosition);
    
    for (int i=0; i<textContainer.size(); i++) {
        
        TextData textData;
        textData=textContainer.at(i);
        
        currentTextYOffset=lastTextYOffset-textData.yOffset;
        
        translateBy(lastTextXAdvance/director->getDisplayWidth(),currentTextYOffset/director->getDisplayHeight(), 0.0);
        
        openGlManager->updateImageDimension(textData.width, textData.height,fontLoader->fontAtlasWidth,fontLoader->fontAtlasHeight);
        openGlManager->updateVertexObjectBuffer();
        
        //set the offset for the sprite
        std::vector<float> data{textData.x,textData.y};
        
        openGlManager->updateCustomUniforms("offset", data);
        
        openGlManager->draw();
        
        lastTextYOffset=textData.yOffset;
        lastTextXAdvance=textData.xAdvance+textSpacing;
        
    }
    
    //reset to initial position
    translateTo(initPosition);
    
}

}
