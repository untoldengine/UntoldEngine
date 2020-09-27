//
//  U4DText.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DText.h"
#include "U4DDirector.h"
#include "U4DRenderFont.h"
#include "U4DResourceLoader.h"

namespace U4DEngine {
    
    U4DText::U4DText(std::string uFontName):currentTextContainerSize(0){
        
        renderManager=new U4DRenderFont(this);
            
        setShader("vertexFontImageShader", "fragmentFontImageShader"); 
        
        U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
        
        resourceLoader->loadFontToText(this, uFontName);
        
        setFont();
            
        textContainer.clear();
        
    }
        
    U4DText::~U4DText(){
        
        delete renderManager;
        
    }

    U4DText::U4DText(const U4DText& value){

    }

    U4DText& U4DText::operator=(const U4DText& value){
        
        return *this;

    }

    void U4DText::setFont(){
        
        const char * fontAtlasImage = fontData.texture.c_str();
        
        renderManager->setTexture0(fontAtlasImage);
        
        
    }

    void U4DText::setText(float uFloatValue){
        
        char value[10];
        sprintf(value, "%0.4f", uFloatValue);

        setText(value);
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
            
            for (int j=0; j<fontData.characterData.size(); j++) {
                
                if (text[i]==*fontData.characterData[j].letter) {
                    
                    //copy the chars into the textContainer
                    TEXTDATA textData;
                    
                    textData.x=fontData.characterData[j].x/fontData.fontAtlasWidth;
                    textData.y=fontData.characterData[j].y/fontData.fontAtlasHeight;
                    textData.width=fontData.characterData[j].width;
                    textData.height=fontData.characterData[j].height;
                    
                    textData.xOffset=fontData.characterData[j].xoffset;
                    textData.yOffset=fontData.characterData[j].yoffset;
                    textData.xAdvance=fontData.characterData[j].xadvance;
                    
                    textData.letter=fontData.characterData[j].letter;
                    
                    textContainer.push_back(textData);
                    
                }
            }
            
        }
        
    }

    void U4DText::loadText(){
        
        float lastCharYOffset=0.0;
        float currentCharYOffset=0.0;
        float lastCharXAdvance=0.0;
        
        for (int i=0; i<textContainer.size(); i++) {
            
            TEXTDATA textData;
            
            textData=textContainer.at(i);
            
            currentCharYOffset=1.0-textData.yOffset;
            
            U4DVector3n charPositionOffset(lastCharXAdvance,currentCharYOffset, 0.0);
            
            U4DVector2n charUV(textData.x,textData.y);
            
            setTextDimension(charPositionOffset,charUV,i,textData.width,textData.height);
            
            lastCharYOffset=textData.yOffset;
            
            lastCharXAdvance+=(textData.xAdvance);
            
        }
        
    }

    void U4DText::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DText::setTextDimension(U4DVector3n &uFontPositionOffset, U4DVector2n &uFontUV, int uTextCount, float uTextWidth,float uTextHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float widthFontTexture=uTextWidth/fontData.fontAtlasWidth;
        float heightFontTexture=uTextHeight/fontData.fontAtlasHeight;
        
        float width=uTextWidth/director->getDisplayWidth();
        float height=uTextHeight/director->getDisplayHeight();
        float depth=0.0;
        
        uFontPositionOffset.x/=director->getDisplayWidth();
        uFontPositionOffset.y/=director->getDisplayHeight();
        
        
        
        //vertices
        U4DVector3n v1(width,height,depth);
        U4DVector3n v4(width,-height,depth);
        U4DVector3n v2(-width,-height,depth);
        U4DVector3n v3(-width,height,depth);
        
        v1+=uFontPositionOffset;
        v2+=uFontPositionOffset;
        v3+=uFontPositionOffset;
        v4+=uFontPositionOffset;
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v4);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        
        //texture
        U4DVector2n t4(0.0,0.0);  //top left
        U4DVector2n t1(1.0*widthFontTexture,0.0);  //top right
        U4DVector2n t3(0.0,1.0*heightFontTexture);  //bottom left
        U4DVector2n t2(1.0*widthFontTexture,1.0*heightFontTexture);  //bottom right
        
        t4+=uFontUV;
        t1+=uFontUV;
        t3+=uFontUV;
        t2+=uFontUV;
        
        bodyCoordinates.addUVDataToContainer(t1);
        bodyCoordinates.addUVDataToContainer(t2);
        bodyCoordinates.addUVDataToContainer(t3);
        bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        
        i1.x=i1.x+4*uTextCount;
        i1.y=i1.y+4*uTextCount;
        i1.z=i1.z+4*uTextCount;
        
        i2.x=i2.x+4*uTextCount;
        i2.y=i2.y+4*uTextCount;
        i2.z=i2.z+4*uTextCount;
        
        //index
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        
        
    }
    
    

}
