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
#include "U4DDualQuaternion.h"
#include "U4DEntity.h"

#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {
 
/**
 @brief The U4DVisibleEntity class represents all visible entities in a game
 */
class U4DVisibleEntity:public U4DEntity{
    
private:
    
protected:
    
    std::string vertexShader;
    
    std::string fragmentShader;
    
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
     @brief Method which loads all rendering information for the entiy
     */
    void loadRenderingInformation();
    
    //metal methods
    U4DRenderManager *renderManager;
    
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
    
    virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){};
    
    void setShader(std::string uVertexShaderName, std::string uFragmentShaderName);
    
    std::string getVertexShader();
    
    std::string getFragmentShader();
};
    
}

#endif /* defined(__UntoldEngine__U4DVisibleEntity__) */
