//
//  U4DTextureData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DTextureData__
#define __UntoldEngine__U4DTextureData__

#include <iostream>
#include <string>

namespace U4DEngine {
    
class U4DTextureData{
    
private:
    
public:
    
    U4DTextureData(){};
    ~U4DTextureData(){};
    
    std::string emissionTexture;
    std::string diffuseTexture;
    std::string ambientTexture;
    std::string specularTexture;
    std::string normalBumpTexture;
    
    void setEmissionTexture(std::string uData);
    void setDiffuseTexture(std::string uData);
    void setAmbientTexture(std::string uData);
    void setSpecularTexture(std::string uData);
    void setNormalBumpTexture(std::string uData);
};
    
}

#endif /* defined(__UntoldEngine__U4DTextureData__) */
