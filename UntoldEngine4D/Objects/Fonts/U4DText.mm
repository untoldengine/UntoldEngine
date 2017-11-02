//
//  U4DText.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DText.h"
#include "U4DDirector.h"
#include "U4DRenderFont.h"
#include "U4DFontLoader.h"

namespace U4DEngine {
    
    U4DText::U4DText(U4DFontLoader* uFontLoader, float uTextSpacing):textSpacing(uTextSpacing),currentTextContainerSize(0){
        
        renderManager=new U4DRenderFont(this);
            
        setShader("vertexFontImageShader", "fragmentFontImageShader");
        
        fontLoader=uFontLoader;
       
        setFont();
            
        textContainer.clear();
        
    }
        
    U4DText::~U4DText(){
        
        delete renderManager;
        delete fontLoader;
        
    }

    U4DText::U4DText(const U4DText& value){

    }

    U4DText& U4DText::operator=(const U4DText& value){
        
        return *this;

    }

    void U4DText::setFont(){
        
        const char * fontAtlasImage = fontLoader->fontAtlasImage.c_str();
        
        renderManager->setDiffuseTexture(fontAtlasImage);
        
        
    }

    void U4DText::setText(const char* uText){
        
        text=uText;
        
        if (textContainer.size()==0) {
            
            parseText(uText);
            
            loadText();
            
            renderManager->loadRenderingInformation();
            
        }else{
            
            //store a copy of the previous text container size
            currentTextContainerSize=(int)textContainer.size();
            
            //parse new text
            parseText(uText);
            
            renderManager->clearModelAttributeData();
            
            loadText();
            
            //test if textcontainer size is equal to currenttext container size
            if (textContainer.size()==currentTextContainerSize) {
                
                renderManager->updateRenderingInformation();
                
            }else{
                
                renderManager->modifyRenderingInformation();
            }
            
        }
    }
        
    void U4DText::parseText(const char* uText){
        
        textContainer.clear(); //clear the text container
        
        //break down the text
        for (int i=0; i<strlen(text); i++) {
            
            for (int j=0; j<fontLoader->fontData.size(); j++) {
                
                if (text[i]==*fontLoader->fontData[j].letter) {
                    
                    //copy the chars into the textContainer
                    TEXTDATA textData;
                    
                    textData.x=fontLoader->fontData[j].x/fontLoader->fontAtlasWidth;
                    textData.y=fontLoader->fontData[j].y/fontLoader->fontAtlasHeight;
                    textData.width=fontLoader->fontData[j].width;
                    textData.height=fontLoader->fontData[j].height;
                    
                    textData.xOffset=fontLoader->fontData[j].xoffset;
                    textData.yOffset=fontLoader->fontData[j].yoffset;
                    textData.xAdvance=fontLoader->fontData[j].xadvance;
                    
                    textData.letter=fontLoader->fontData[j].letter;
                    
                    textContainer.push_back(textData);
                    
                }
            }
            
        }
        
    }

    void U4DText::loadText(){
        
        float lastTextYOffset=0.0;
        float currentTextYOffset=0.0;
        float lastTextXAdvance=0.0;
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        for (int i=0; i<textContainer.size(); i++) {
            
            TEXTDATA textData;
            
            textData=textContainer.at(i);
            
            currentTextYOffset=1.0-textData.yOffset;
            
            U4DVector3n fontPositionOffset(lastTextXAdvance/director->getDisplayWidth(),currentTextYOffset/director->getDisplayHeight(), 0.0);
            
            U4DVector2n fontUV(textData.x,textData.y);
            
            renderManager->setTextDimension(fontPositionOffset,fontUV,i,textData.width,textData.height,fontLoader->fontAtlasWidth,fontLoader->fontAtlasHeight);
            
            lastTextYOffset=textData.yOffset;
            
            lastTextXAdvance=lastTextXAdvance+textData.xAdvance+textSpacing;
            
        }
        
    }
        
    void U4DText::setTextSpacing(float uTextSpacing){
        
        textSpacing=uTextSpacing;
        
    }

    void U4DText::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }

}
