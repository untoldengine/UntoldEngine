//
//  U4DTextureData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
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
    U4DTextureData();
    
    /**
     @brief Destructor for the class
     */
    ~U4DTextureData();
    
    /**
     @brief Name of the texture representing the texture0
     */
    std::string texture0;
    
    /**
     @brief Name of the texture representing the texture1
     */
    std::string texture1;
    
    /**
     @brief Name of the texture representing the texture2
     */
    std::string texture2;
    
    /**
     @brief Name of the texture representing the texture3
     */
    std::string texture3;
    
    /**
     @brief Name of the texture representing the normal map texture
     */
    std::string normalBumpTexture;
    
    
    
    /**
     @brief Method which sets the texture0
     
     @param uData string data with the name of the texture
     */
    void setTexture0(std::string uData);
    
    /**
     @brief Method which sets the texture1
     
     @param uData string data with the name of the texture
     */
    void setTexture1(std::string uData);
    
    /**
     @brief Method which sets the texture2
     
     @param uData string data with the name of the texture
     */
    void setTexture2(std::string uData);
    
    /**
     @brief Method which sets the texture3
     
     @param uData string data with the name of the texture
     */
    void setTexture3(std::string uData);
    
    /**
     @brief Method which sets the normal-map texture
     
     @param uData string data with the name of the normal-map texture
     */
    void setNormalBumpTexture(std::string uData);
};
    
}

#endif /* defined(__UntoldEngine__U4DTextureData__) */
