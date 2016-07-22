//
//  U4DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DModel__
#define __UntoldEngine__U4DModel__

#include <iostream>
#include "U4DVisibleEntity.h"
#include "U4DMatrix3n.h"
#include "U4DOpenGL3DModel.h" 
#include "U4DVertexData.h"
#include "U4DMaterialData.h"
#include "U4DTextureData.h"
#include "U4DArmatureData.h"
#include "U4DAnimation.h"
#include "CommonProtocols.h"


namespace U4DEngine {
    
    class U4DModel:public U4DVisibleEntity{
        
    private:
        
        bool hasMaterial;
        
        bool hasTextures;
        
        bool hasAnimation;
        
        
        
    protected:
        
    public:
        
        U4DVertexData bodyCoordinates;
        
        U4DMaterialData materialInformation;
        
        U4DTextureData textureInformation;
        
        U4DArmatureData *armatureManager;
        
        std::vector<U4DMatrix4n> armatureBoneMatrix;
        
        U4DModel();
        
        ~U4DModel();
        

        U4DModel(const U4DModel& value);

        U4DModel& operator=(const U4DModel& value);
        
        virtual void update(double dt){};
        
        void draw() final;
        
        void drawDepthOnFrameBuffer();

        void setShader(std::string uShader);
        
        void setHasMaterial(bool uValue);
        
        void setHasTexture(bool uValue);
        
        void setHasAnimation(bool uValue);
        
        bool getHasMaterial();
        
        bool getHasTexture();
        
        bool getHasAnimation();
     
    };
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
