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
        
    }TOUCHSTATE;


    typedef struct{
        
        const char* name;
        std::vector<float> data;
        GLint location;
        
    }CUSTOMUNIFORMS;

    typedef struct{
        
        const char* name;
        float x;
        float y;
        int width;
        int height;
        
    }SPRITEDATA;


    typedef struct {
        
        std::vector<const char*> animationSprites;
        float delay;
        
    }SPRITEANIMATION;


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
        
    }FONTDATA;

    typedef struct{

        float x;
        float y;
        float width;
        float height;
        float xOffset;
        float yOffset;
        float xAdvance;
        const char* letter;
    }TEXTDATA;

    typedef struct{
        
        std::string name;
        float time;
        U4DDualQuaternion animationSpaceTransform;
        
    }KEYFRAMEDATA;

    typedef struct{
      
        std::string name;
        std::vector<KEYFRAMEDATA> keyframes;
        
    }ANIMATIONDATA;

    typedef enum{
        
        LIGHT,
        MODEL,
        CAMERA,
        PARENT
        
    }ENTITYTYPE;


    typedef struct{
        
        U4DPoint3n sa; //support point in sa
        U4DPoint3n sb; //support point in sb
        U4DPoint3n minkowskiPoint; //Minkowski difference point
        
    }SIMPLEXDATA;
    
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
    
    //CONVEX HULL STRUCTURES
    typedef struct CONVEXHULLVERTEXSTRUCT CONVEXVERTEX;
    typedef CONVEXVERTEX *CONVEXHULLVERTEX;
    
    typedef struct CONVEXHULLEDGESTRUCT CONVEXEDGE;
    typedef CONVEXEDGE *CONVEXHULLEDGE;
    
    typedef struct CONVEXHULLFACESTRUCT CONVEXFACE;
    typedef CONVEXFACE *CONVEXHULLFACE;
    
    struct CONVEXHULLVERTEXSTRUCT{
        int v[3];
        int vNum;
        CONVEXHULLEDGE duplicate;
        bool onHull;
        bool processed;
        CONVEXHULLVERTEX next,prev;
    };
    
    struct CONVEXHULLEDGESTRUCT{
        CONVEXHULLFACE adjFace[2];
        CONVEXHULLVERTEX endPts[2];
        CONVEXHULLFACE newFace;
        bool shouldDelete;
        CONVEXHULLEDGE next,prev;
    };
    
    struct CONVEXHULLFACESTRUCT{
        CONVEXHULLEDGE edge[3];
        CONVEXHULLVERTEX vertex[3];
        bool visible;
        CONVEXHULLFACE next,prev;
    };
    
}




#endif
