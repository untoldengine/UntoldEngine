//
//  U4DMaterialData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DMaterialData__
#define __UntoldEngine__U4DMaterialData__

#include <iostream>
#include <vector>
#include "U4DColorData.h"


namespace U4DEngine {
    
/**
 @brief The U4DMaterialData class holds material information for a 3D entity
 */
class U4DMaterialData{
    
    private:
        
    public:
    
    /**
     @brief Constructor for the class
     */
    U4DMaterialData();
    
    /**
     @brief Destructor for the class
     */
    ~U4DMaterialData();
    
    /**
     @brief Container which holds diffuse material color information for the 3D entity
     */
    std::vector<U4DColorData> diffuseMaterialColorContainer;
    
    /**
     @brief Container which holds specular material color information for the 3D entity
     */
    std::vector<U4DColorData> specularMaterialColorContainer;
    
    /**
     @brief Container which holds diffuse material intensity information for the 3D entity
     */
    std::vector<float> diffuseMaterialIntensityContainer;
    
    /**
     @brief Container which holds specular material intensity information for the 3D entity
     */
    std::vector<float> specularMaterialIntensityContainer;
    
    /**
     @brief Container which holds specular material shininess information for the 3D entity
     */
    std::vector<float> specularMaterialHardnessContainer;
    
    /**
     @brief Container which holds material index information for the 3D entity
     */
    std::vector<float> materialIndexColorContainer;
    
    /**
     @brief Method which adds diffuse material color information into the container
     
     @param uData Diffuse material data for the 3D entity
     */
    void addDiffuseMaterialDataToContainer(U4DColorData& uData);
    
    /**
     @brief Method which adds specular material color information into the container
     
     @param uData Specular material data for the 3D entity
     */
    void addSpecularMaterialDataToContainer(U4DColorData& uData);
    
    /**
     @brief Method which add diffuse material intensity information into the container
     
     @param uData Diffuse intensity data for the 3D entity
     */
    void addDiffuseIntensityMaterialDataToContainer(float &uData);
    
    /**
     @brief Method which adds specular material intensity information into the container
     
     @param uData Specular intensity data for the 3D entity
     */
    void addSpecularIntensityMaterialDataToContainer(float &uData);
    
    /**
     @brief Method which adds specular shininess information into the container
     
     @param uData Specular shininess data for the 3D entity
     */
    void addSpecularHardnessMaterialDataToContainer(float &uData);
    
    /**
     @brief Method which adds material index data into the container
     
     @param uData Material Index data for the 3D entity
     */
    void addMaterialIndexDataToContainer(float &uData);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DMaterialData__) */
