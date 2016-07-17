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
#include "U4DPoint3n.h"
#include "U4DTriangle.h"


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


    typedef struct{
        
        U4DPoint3n sa; //support point in sa
        U4DPoint3n sb; //support point in sb
        U4DPoint3n minkowskiPoint; //Minkowski difference point
        
    }U4DSimplexStruct;
    
    typedef struct{
        
        U4DVector3n vertex;
        bool isDuplicate;
        
    }POLYTOPEVERTEX;

    typedef struct{
        
        U4DSegment segment;
        bool isDuplicate;
        
    }POLYTOPEEDGES;
    
    typedef struct{
        
        U4DTriangle triangle;
        std::vector<POLYTOPEEDGES> edges;
        std::vector<POLYTOPEVERTEX> vertices;
        bool isSeenByPoint;
        int index;
        
    }POLYTOPEFACES;
    
    typedef struct{
        
        std::vector<POLYTOPEVERTEX> vertex;
        std::vector<POLYTOPEEDGES> edges;
        std::vector<POLYTOPEFACES> faces;
        bool isValid;
        
    }CONVEXHULL;
    
    typedef struct{
        
        std::vector<U4DVector3n> contactPoints;
        U4DVector3n normalCollisionVector;
        U4DPoint3n collisionClosestPoint;
        
        
    }COLLISIONMANIFOLDONODE;
    
}




#endif
