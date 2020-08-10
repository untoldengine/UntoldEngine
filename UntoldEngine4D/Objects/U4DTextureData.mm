//
//  U4DTextureData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DTextureData.h"

namespace U4DEngine {

U4DTextureData::U4DTextureData(){
    
}

U4DTextureData::~U4DTextureData(){
    
}
    
void U4DTextureData::setTexture0(std::string uData){
    
    texture0=uData;
}

void U4DTextureData::setTexture1(std::string uData){
    
    texture1=uData;
}

void U4DTextureData::setTexture2(std::string uData){
    
    texture2=uData;
}

void U4DTextureData::setTexture3(std::string uData){
    
    texture3=uData;
}

void U4DTextureData::setNormalBumpTexture(std::string uData){
    
    normalBumpTexture=uData;
}

}
