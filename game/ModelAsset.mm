//
//  ModelAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "ModelAsset.h"

ModelAsset::ModelAsset(){
    
}

ModelAsset::~ModelAsset(){
    
}

void ModelAsset::init(const char* uModelName, const char* uBlenderFile, const char* uTextureNormal){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(true);
        
        setNormalMapTexture(uTextureNormal);
        
        loadRenderingInformation();
    }
}

void ModelAsset::update(double dt){
    
}
