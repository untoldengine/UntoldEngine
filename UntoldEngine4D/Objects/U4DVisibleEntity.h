//
//  U4DVisibleEntity.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DVisibleEntity__
#define __UntoldEngine__U4DVisibleEntity__

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include "CommonProtocols.h"
#include "U4DDualQuaternion.h"
#include "U4DEntity.h"

#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {
 
/**
 @ingroup gameobjects
 @brief The U4DVisibleEntity class represents all visible entities in a game
 */
class U4DVisibleEntity:public U4DEntity{
    
private:
    
protected:
    
    /**
     @brief name of the vertex shader used for rendering
     */
    std::string vertexShader;
    
    /**
     @brief name of the fragment shader used for rendering
     */
    std::string fragmentShader;
    
    /*
     @todo document this
     */
    std::string offscreenVertexShader;
    
    /*
     @todo document this
     */
    std::string offscreenFragmentShader;
    
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
     @brief Method which updates the states of the entity
     
     @param dt time-step value
     */
    virtual void update(double dt){};
    
    /**
     @todo document this
     */
    virtual void updateAllUniforms(){};
    
    /**
     @brief Method which loads all rendering information for the entiy
     */
    void loadRenderingInformation();
    
    //metal methods
    
    /**
     @brief pointer to the rendering manager
     */
    U4DRenderManager *renderManager;
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
    
    /**
     * @brief Renders the shadow for a 3D entity
     * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
     *
     * @param uRenderShadowEncoder Metal encoder object for the current entity
     * @param uShadowTexture Texture shadow for the current entity
     */
    virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){};
    
    /*
     @todo document this
     */
    virtual void renderOffscreen(id <MTLRenderCommandEncoder> uRenderOffscreenEncoder, id<MTLTexture> uOffscreenTexture){};
    
    /**
     @brief sets the shader used for rendering the entity

     @param uVertexShaderName name of the vertex shader
     @param uFragmentShaderName name of the fragment shader
     */
    void setShader(std::string uVertexShaderName, std::string uFragmentShaderName);
    
    /*
     @todo document this
     */
    void setOffscreenShader(std::string uVertexShaderName, std::string uFragmentShaderName);
    
    /**
     @brief get the name of the vertex shader

     @return name of the vertex shader
     */
    std::string getVertexShader();
    
    
    /**
     @brief get the name of the fragment shader

     @return name of the fragment shader
     */
    std::string getFragmentShader();
    
    /**
     @todo document this
     */
    std::string getVertexOffscreenShader();
    
    /**
     @todo document this
     */
    std::string getFragmentOffscreenShader();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DVisibleEntity__) */
