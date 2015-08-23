//
//  CommonProtocols.h
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/5/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef MVCTemplateV001_CommonProtocols_h
#define MVCTemplateV001_CommonProtocols_h

#include <vector>
#include "U4DDualQuaternion.h"

namespace U4DEngine {
    
    typedef enum {
        
        rTouchesBegan,
        rTouchesMoved,
        rTouchesEnded,
        rTouchesPressed,
        rTouchesReleased,
        rTouchesNull
        
    }TouchState;


    typedef struct{
        
        const char* name;
        std::vector<float> data;
        GLint location;
        
    }CustomUniforms;

    typedef struct{
        
        const char* name;
        float x;
        float y;
        int width;
        int height;
        
    }SpriteData;


    typedef struct {
        
        std::vector<const char*> animationSprites;
        float delay;
        
    }SpriteAnimation;


    typedef struct{
        
        int ID;
        float x;
        float y;
        float width;  //width of character
        float height; //height of character
        float xoffset;
        float yoffset;
        float xadvance;
        int infoFontSize; //size of whole fonts
        const char *letter;
        
    }FontData;

    typedef struct{

        float x;
        float y;
        float width;
        float height;
        float xOffset;
        float yOffset;
        float xAdvance;
        const char* letter;
    }TextData;

    typedef struct{
        
        std::string name;
        float time;
        U4DDualQuaternion animationSpaceTransform;
        
    }KeyframeData;

    typedef struct{
      
        std::string name;
        std::vector<KeyframeData> keyframes;
        
    }AnimationData;

    typedef enum{
        
        LIGHT,
        MODEL,
        PARENT
        
    }ENTITYTYPE;

    typedef enum{
        
        SPHERE,
        AABB
        
    }BOUNDINGTYPE;


    
    
}




#endif
