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

/**
 @brief The U4DTextureData class holds texture information for a 3D entity
 */
class U4DTextureData{
    
private:
    
public:

    /**
     @brief Constructor for the class
     */
    U4DTextureData(){};
    
    /**
     @brief Destructor for the class
     */
    ~U4DTextureData(){};
    
    /**
     @brief Name of the texture representing the emission component
     */
    std::string emissionTexture;
    
    /**
     @brief Name of the texture representing the diffuse component
     */
    std::string diffuseTexture;
    
    /**
     @brief Name of the texture representing the ambient component
     */
    std::string ambientTexture;
    
    /**
     @brief Name of the texture representing the specular component
     */
    std::string specularTexture;
    
    /**
     @brief Name of the texture representing the normal map texture
     */
    std::string normalBumpTexture;
    
    /**
     @brief Method which sets the emission texture
     
     @param uData string data with the name of the emission texture
     */
    void setEmissionTexture(std::string uData);
    
    /**
     @brief Method which sets the diffuse texture
     
     @param uData string data with the name of the diffuse texture
     */
    void setDiffuseTexture(std::string uData);
    
    /**
     @brief Method which sets the ambient texture
     
     @param uData string data with the name of the ambient texture
     */
    void setAmbientTexture(std::string uData);
    
    /**
     @brief Method which sets the specular texture
     
     @param uData string data with the name of the specular texture
     */
    void setSpecularTexture(std::string uData);
    
    /**
     @brief Method which sets the normal-map texture
     
     @param uData string data with the name of the normal-map texture
     */
    void setNormalBumpTexture(std::string uData);
};
    
}

#endif /* defined(__UntoldEngine__U4DTextureData__) */
