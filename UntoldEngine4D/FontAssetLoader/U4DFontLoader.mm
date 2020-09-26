//
//  U4DFontLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DFontLoader.h"
#include "tinyxml2.h"

namespace U4DEngine {
    
U4DFontLoader::U4DFontLoader(){

}

U4DFontLoader::~U4DFontLoader(){

}
    
void U4DFontLoader::loadFontAssetFile(std::string uFontAtlasFile,std::string uFontAtlasImage){
    
    const char * atlasFile = uFontAtlasFile.c_str();
    
    bool loadOk=doc.LoadFile(atlasFile);
    
    if (!loadOk) {
        
        std::cout<<"Font Asset "<<uFontAtlasFile<<" loaded successfully"<<std::endl;
        
        loadFont();
        
        fontAtlasImage=uFontAtlasImage;
        
    }else{
        std::cout<<"Font Asset "<<uFontAtlasFile<<"was not found. Loading failed"<<std::endl;
    
    }
 
    
}


void U4DFontLoader::loadFont(){

    
    tinyxml2::XMLNode* font = doc.FirstChildElement("font");
    
    tinyxml2::XMLElement* infoElem = font->FirstChildElement("info");
    const char* infoFontSize=infoElem->Attribute("size");
    
    tinyxml2::XMLElement* commonElem = font->FirstChildElement("common");
    const char* lineHeight=commonElem->Attribute("lineHeight");
    const char* base=commonElem->Attribute("base");
    const char* atlasWidth=commonElem->Attribute("scaleW");
    const char* atlasHeight=commonElem->Attribute("scaleH");
    
    float lineHeightValue=atof(lineHeight);
    float baseValue=atof(base);
    
    float yOffsetReScale=lineHeightValue-baseValue;
    
    fontAtlasWidth=atof(atlasWidth);
    fontAtlasHeight=atof(atlasHeight);
    

    tinyxml2::XMLElement* pagesElem = font->FirstChildElement("pages");
    tinyxml2::XMLElement* pageElem=pagesElem->FirstChildElement("page");
    
    
    tinyxml2::XMLElement* elem = font->FirstChildElement("chars");
    
    for(tinyxml2::XMLElement* subElem = elem->FirstChildElement("char"); subElem != NULL; subElem = subElem->NextSiblingElement("char"))
    {
        
        //set up the fontData
        FONTDATA ufontData;
        
        const char* ID = subElem->Attribute("id");
        ufontData.ID=atoi(ID);
        
        const char* x=subElem->Attribute("x");
        ufontData.x=atof(x);
        
        const char* y=subElem->Attribute("y");
        ufontData.y=atof(y);
        
        const char* width=subElem->Attribute("width");
        ufontData.width=atof(width);
        
        const char* height=subElem->Attribute("height");
        ufontData.height=atof(height);
        
        const char* xoffset=subElem->Attribute("xoffset");
        ufontData.xoffset=atof(xoffset);
        
        const char* yoffset=subElem->Attribute("yoffset");
        ufontData.yoffset=atof(yoffset);
        
        
        const char* xadvance=subElem->Attribute("xadvance");
        ufontData.xadvance=atof(xadvance);
        
        ufontData.infoFontSize=atoi(infoFontSize);
        
        if (strcmp(subElem->Attribute("letter"), "space") == 0) {
            
            ufontData.letter=" ";
            
        }        
        else{
            
            ufontData.letter=subElem->Attribute("letter");
            
            if (strcmp(ufontData.letter,"y")==0||strcmp(ufontData.letter,"p")==0||strcmp(ufontData.letter,"g")==0||strcmp(ufontData.letter,"q")==0||strcmp(ufontData.letter,"j")==0) {
                
                ufontData.yoffset=yOffsetReScale+ufontData.yoffset;
                
            }
        }
        
        
        fontData.push_back(ufontData);
    }

}

}

