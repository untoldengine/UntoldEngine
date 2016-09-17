//
//  U4DVisibleEntity.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVisibleEntity__
#define __UntoldEngine__U4DVisibleEntity__

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include "CommonProtocols.h"
#include "U4DOpenGLManager.h"
#include "U4DDualQuaternion.h"
#include "U4DEntity.h"

#define OPENGL_ES

namespace U4DEngine {
 
/**
 @brief The U4DVisibleEntity class represents all visible entities in a game
 */
class U4DVisibleEntity:public U4DEntity{
    
private:
    
protected:
    
public:
    
    /**
     @brief Constructor for the class
     */
    U4DVisibleEntity();
    
    /**
     @brief Destructor for the class
     */
    virtual ~U4DVisibleEntity(){}
    
    /**
     @brief Copy constructor for the visible entity
     */
    U4DVisibleEntity(const U4DVisibleEntity& value);

    /**
     @brief Copy constructor for the visible entity
     
     @param value Entity to copy
     
     @return Returns a copy of the entity object
     */
    U4DVisibleEntity& operator=(const U4DVisibleEntity& value);
    
    /**
     @brief Pointer to the openGL manager class in charge of rendering the entity
     */
    U4DOpenGLManager   *openGlManager;
    
    /**
     @brief Method which starts the entity rendering operation
     */
    virtual void draw(){};
    
    /**
     @brief Method which updates the states of the entity
     
     @param dt time-step value
     */
    virtual void update(double dt){};
    
    /**
     @brief Method which adds a custom uniform to the entity's shader
     
     @param uName Name of uniform
     @param uData vector containing float data for uniform
     */
    void addCustomUniform(const char* uName,std::vector<float> uData);
    
    /**
     @brief Method which adds a custom uniform to the entity's shader
     
     @param uName Name of uniform
     @param uData 3D vector data for uniform
     */
    void addCustomUniform(const char* uName,U4DVector3n uData);
    
    /**
     @brief Method which adds a custom uniform to the entity's shader
     
     @param uName Name of uniform
     @param uData 4D vector data for uniform
     */
    void addCustomUniform(const char* uName,U4DVector4n uData);
    
    /**
     @brief Method which updates the data for the custom uniform
     
     @param uName Name of uniform
     @param uData data to update
     */
    void updateUniforms(const char* uName,std::vector<float> uData);
    
    /**
     @brief Method which updates the data for the custom uniform
     
     @param uName Name of uniform
     @param uData data to update
     */
    void updateUniforms(const char* uName,U4DVector3n uData);
    
    /**
     @brief Method which updates the data for the custom uniform
     
     @param uName Name of uniform
     @param uData data to update
     */
    void updateUniforms(const char* uName,U4DVector4n uData);
    
    /**
     @brief Method which loads all rendering information for the entiy
     */
    void loadRenderingInformation();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DVisibleEntity__) */
