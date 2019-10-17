//
//  CommonProtocols.h
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/5/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef MVCTemplateV001_CommonProtocols_h
#define MVCTemplateV001_CommonProtocols_h

#include <vector>
#include "U4DDualQuaternion.h"
#include "U4DPoint3n.h"
#include "U4DTriangle.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"

namespace U4DEngine {
    
    /**
     @brief The TOUCHSTATE enum holds the different touch states
     */
    typedef enum {
        
        /**
         @brief Touch event began
         */
        rTouchesBegan,
        
        /**
         @brief Touch event moved
         */
        rTouchesMoved,
        
        /**
         @brief Touch event ended
         */
        rTouchesEnded,
        
        /**
         @brief Touch event is null
         */
        rTouchesNull
        
    }TOUCHSTATE;

    /**
     @brief The SPRITEDATA structure holds sprites information
     */
    typedef struct{
        
        /**
         @brief Sprite name
         */
        const char* name;
        
        /**
         @brief Sprite x-coordinate position
         */
        float x;
        
        /**
         @brief Sprite y-coordinate position
         */
        float y;
        
        /**
         @brief Sprite width
         */
        int width;
        
        /**
         @brief Sprite height
         */
        int height;
        
    }SPRITEDATA;


    /**
     @brief The SPRITEANIMATION structure holds sprite animation data
     */
    typedef struct {
        
        /**
         @brief Vector containing the names of the sprites to be used in the animation
         */
        std::vector<const char*> animationSprites;
        
        /**
         @brief Sprite animation delay
         */
        float delay;
        
    }SPRITEANIMATIONDATA;


    /**
     @brief The FONTDATA structure holds font character data
     */
    typedef struct{
        
        /**
         @brief Font character ID
         */
        int ID;
        
        /**
         @brief Font character x-coordinate position
         */
        float x;
        
        /**
         @brief Font character y-coordinate position
         */
        float y;
        
        /**
         @brief Font character width
         */
        float width;
        
        /**
         @brief Font character height
         */
        float height;
        
        /**
         @brief Font character x-offset position
         */
        float xoffset;
        
        /**
         @brief Font character y-offset position
         */
        float yoffset;
        
        /**
         @brief Font character x-advance
         */
        float xadvance;
        
        /**
         @brief Size of font
         */
        int infoFontSize;
        
        /**
         @brief Font character letter name
         */
        const char *letter;
        
    }FONTDATA;

    /**
     @brief The TEXTDATA structure holds text information
     */
    typedef struct{
        /**
         @brief Text x-coordinate position
         */
        float x;
        
        /**
         @brief Text y-coordinate position
         */
        float y;
        
        /**
         @brief Text width
         */
        float width;
        
        /**
         @brief Text height
         */
        float height;
        
        /**
         @brief Text x-offset position
         */
        float xOffset;
        
        /**
         @brief Text y-offset position
         */
        float yOffset;
        
        /**
         @brief Text x-advance
         */
        float xAdvance;
        
        /**
         @brief Text letter name
         */
        const char* letter;
    }TEXTDATA;

    /**
     @brief The KEYFRAMEDATA structure holds 3D animation keyframe data
     */
    typedef struct{
        /**
         @brief Keyframe name
         */
        std::string name;
        
        /**
         @brief Keyframe time value
         */
        float time;
        
        /**
         @brief 3D animation space transform-orientation/translation of every armature bone in keyframe
         */
        U4DDualQuaternion animationSpaceTransform;
        
    }KEYFRAMEDATA;

    /**
     @brief The ANIMATIONDATA structure holds 3D animation data
     */
    typedef struct{
      
        /**
         @brief 3D animation name
         */
        std::string name;
        
        /**
         @brief 3D animation keyframes
         */
        std::vector<KEYFRAMEDATA> keyframes;
        
    }ANIMATIONDATA;
    
    /**
     @brief The PARTICLESYSTEMTYPE enum holds data required by the particle system type. It holds the type of emitter to be used for the particle system
     */
    typedef enum{
        
        /**
         @brief Emit particles in a linear shape
         */
        LINEAREMITTER,
        
        /**
         @brief Emit particles in a Torus shape
         */
        TORUSEMITTER,
        
        /**
         @brief Emit particles in a Spherical shape
         */
        SPHERICALEMITTER
        
    }PARTICLESYSTEMTYPE;
    
    /**
     @brief The PARTICLESYSTEMDATA structure holds data required by the particle system
     */
    typedef struct{
        
        /**
         @brief Start color of the particle during the start of emission
         */
        
        U4DVector4n particleStartColor;
        
        /**
         @brief End color of the particle as it nears its life span
         */
        U4DVector4n particleEndColor;
        
        /**
         @brief Color variance for the start color
         */
        U4DVector4n particleStartColorVariance;
        
        /**
         @brief Color variance for the end color
         */
        U4DVector4n particleEndColorVariance;
        
        /**
         @brief position variance of the particle
         */
        U4DVector3n particlePositionVariance;
        
        /**
         @brief emission angle
         */
        float particleEmitAngle;
        
        /**
         @brief emission angle variance
         */
        float particleEmitAngleVariance;
        
        /**
         @brief Distance from the center of the torus to the center of the tube
         */
        float torusMajorRadius=15.0;
        
        /**
         @brief Radius of the torus tube
         */
        float torusMinorRadius=5.0;
        
        /**
         @brief Radius of the sphere
         */
        float sphereRadius=2.0;
        
        /**
         @brief life span of the article
         */
        float particleLife=1.0;
        
        /**
         @brief particle's speed
         */
        float particleSpeed;
        
        /**
         @brief particle's speed variance
         */
        float particleSpeedVariance;
        
        /**
         @brief number of particles the emitter must emit per emission
         */
        int numberOfParticlesPerEmission=1;
        
        /**
         @brief maximum number of particles the emitter can create
         */
        int maxNumberOfParticles=50;
        
        /**
         @brief emission rate
         */
        float emissionRate=1.0;
        
        /**
         @brief emitter duration rate
         */
        float emitterDurationRate=1.0;
        
        /**
         @brief if set to true, the emitter will emit continuously
         */
        bool emitContinuously;
        
        /**
         @brief force of gravity acting on the particle
         */
        U4DVector3n gravity;
        
        /**
         @brief particle emitter type. The emitter can emit the particles in a spherical, torus or linear fashion
         */
        int particleSystemType=0;
        
        /**
         @brief if set to true, the emitter will add noise to the particle's texture.
         */
        bool enableNoise=false;
        
        /**
         @brief Noise frequency. Possible values are 1,2,4,8,16,32
         */
        float noiseDetail=4.0;
        
        /**
         @brief if set to true, the particles color will be blended with the sorrounding colors
         */
        bool enableAdditiveRendering=true;
        
        /**
         @brief particle size
         */
        float particleSize=1.0;
        
        /**
         @brief particle start size
         */
        float startParticleSize=1.0;
        
        /**
         @brief particle start size variance
         */
        float startParticleSizeVariance=0.0;
        
        /**
         @brief particle end size
         */
        float endParticleSize=1.0;
        
        /**
         @brief particle end size variance
         */
        float endParticleSizeVariance=0.0;
        
        /**
         @brief particle's radial acceleration
         */
        float particleRadialAcceleration;
        
        /**
         @brief particle's radial acceleration variance
         */
        float particleRadialAccelerationVariance;
        
        /**
         @brief particle's tangential acceleration
         */
        float particleTangentialAcceleration;
        
        /**
         @brief particle's tangential acceleration variance
         */
        float particleTangentialAccelerationVariance;
        
        /**
         @brief particle's start rotation
         */
        float startParticleRotation;
        
        /**
         @brief particle's start rotation variance
         */
        float startParticleRotationVariance;
        
        /**
         @brief particle's end rotation
         */
        float endParticleRotation;
        
        /**
         @brief particle's end rotation variance
         */
        float endParticleRotationVariance;
        
        /**
         @brief particle system's blending source factor
         */
        int blendingFactorSource;
        
        /**
         @brief particle system's blending destination factor
         */
        int blendingFactorDest;
        
    }PARTICLESYSTEMDATA;
    
    /**
     @brief The ENTITYTYPE enumeration holds the type of an entity
     */
    typedef enum{
        
        /**
         @brief Entity represents a light entity
         */
        LIGHT,
        
        /**
         @brief Entity represents a 3D model entity
         */
        MODEL,
        
        /**
         @brief Entity represents a camera entity
         */
        CAMERA,
        
        /**
         @brief Entity is a 3D parent model entity
         */
        PARENT,
        
        /**
         @brief Entity represents an input controller
         */
        CONTROLLERINPUT
        
    }ENTITYTYPE;


    /**
     @brief The SIMPLEXDATA structure holds data representing a simplex support point and the Minkowski difference
     */
    typedef struct{
        
        /**
         @brief Simplex Support 3D point
         */
        U4DPoint3n sa;
        
        /**
         @brief Simplex Support 3D point
         */
        U4DPoint3n sb;
        
        /**
         @brief 3D point representing a Minkowski difference
         */
        U4DPoint3n minkowskiPoint;
        
    }SIMPLEXDATA;
    
    /**
     @brief The POLYTOPEVERTEX structure holds a polytope vertex representation
     */
    typedef struct{
        
        /**
         @brief 3D vertex representing the polytope vertex
         */
        U4DVector3n vertex;
        
    }POLYTOPEVERTEX;

    /**
     @brief The POLYTOPEEDGES structure holds a polytope edge representation
     */
    typedef struct{
        
        /**
         @brief 3D segment representing a polytope segment
         */
        U4DSegment segment;
        
    }POLYTOPEEDGES;
    
    /**
     @brief The POLYTOPEFACES structure holds a polytope face representation
     */
    typedef struct{
        
        /**
         @brief 3D triangle representing a polytope face
         */
        U4DTriangle triangle;
        
    }POLYTOPEFACES;
    
    /**
     @brief The CONVEXHULL structure holds data representing vertices, edges and faces for a computed convex-hull
     */
    typedef struct{
        /**
         @brief Vector holding convex-hull vertices data
         */
        std::vector<POLYTOPEVERTEX> vertex;
        
        /**
         @brief Vector holding convex-hull edges data
         */
        std::vector<POLYTOPEEDGES> edges;
        
        /**
         @brief Vector holding convex-hull faces data
         */
        std::vector<POLYTOPEFACES> faces;
        
        /**
         @brief Boolean variable which informs if the computed convex-hull is valid
         */
        bool isValid;
        
    }CONVEXHULL;
    
    /**
     @brief The COLLISIONMANIFOLDONODE structure holds collision manifold informaiton such as contact points, collision normal vector and closest collision points
     */
    typedef struct{
        
        /**
         @brief Collision contact points
         */
        std::vector<U4DVector3n> contactPoints;
        
        /**
         @brief Collision normal-vector
         */
        U4DVector3n normalCollisionVector;
        
        /**
         @brief Closest collision points
         */
        U4DPoint3n collisionClosestPoint;
        
        /**
         @brief Angle of collision between normal planes (reference and incident plane)
         */
        float referenceAndIncidentPlaneAngle;
        
        
    }COLLISIONMANIFOLDONODE;
    
    //CONVEX HULL STRUCTURES
    typedef struct CONVEXHULLVERTEXSTRUCT CONVEXVERTEX;
    typedef CONVEXVERTEX *CONVEXHULLVERTEX;
    
    typedef struct CONVEXHULLEDGESTRUCT CONVEXEDGE;
    typedef CONVEXEDGE *CONVEXHULLEDGE;
    
    typedef struct CONVEXHULLFACESTRUCT CONVEXFACE;
    typedef CONVEXFACE *CONVEXHULLFACE;
    
    /**
     @brief The CONVEXHULLVERTEXSTRUCT structure holds vertices information used for the construction of the convex-hull
     */
    struct CONVEXHULLVERTEXSTRUCT{
        /**
         @brief Array containing the components of the vertex
         */
        float v[3];
        
        /**
         @brief total number of vertices
         */
        int vNum;
        
        /**
         @brief duplicate convex hull edge
         */
        CONVEXHULLEDGE duplicate;
        
        /**
         @brief Boolean variable which is used to flag the convex-hull algorithm that the vertex is on-Hull
         */
        bool onHull;
        
        /**
         @brief Boolean variable which is used to flag the convex-hull algorithm that the vertex has been processed
         */
        bool processed;
        
        /**
         @brief Pointer to the Next vertex
         */
        CONVEXHULLVERTEX next;
        
        /**
         @brief Pointer to the Previous vertex
         */
        CONVEXHULLVERTEX prev;
        
    };
    
    /**
     @brief The CONVEXHULLEDGESTRUCT structure holds edges information used during the construction of the convex-hull
     */
    struct CONVEXHULLEDGESTRUCT{
        /**
         @brief Array of faces adjacent to the edge
         */
        CONVEXHULLFACE adjFace[2];
        
        /**
         @brief Array of endpoint vertices composing the edge
         */
        CONVEXHULLVERTEX endPts[2];
        
        /**
         @brief New face in convex-hull
         */
        CONVEXHULLFACE newFace;
        
        /**
         @brief Boolean variable which informs the convex-hull algorithm that the edge should be deleted
         */
        bool shouldDelete;
        
        /**
         @brief Pointer to the the Next edge
         */
        CONVEXHULLEDGE next;
        
        /**
         @brief Pointer to the Previous edge
         */
        CONVEXHULLEDGE prev;
    };
    
    /**
     @brief The CONVEXHULLFACESTRUCT structure holds faces information used during the construction of the convex-hull
     */
    struct CONVEXHULLFACESTRUCT{
        /**
         @brief Array of edges composing the current face
         */
        CONVEXHULLEDGE edge[3];
        
        /**
         @brief Array of vertices composing the current face
         */
        CONVEXHULLVERTEX vertex[3];
        
        /**
         @brief Boolean algebra which informs the convex-hull algorithm that the face is seen by a point
         */
        bool visible;
        
        /**
         @brief Pointer to the Next face
         */
        CONVEXHULLFACE next;
        
        /**
         @brief Pointer to the Previous face
         */
        CONVEXHULLFACE prev;
    };
    
    /**
     @brief The INERTIATENSORTYPE enum holds information about the different geometrical mesh types used to calculate the Inertia Tensor
     */
    typedef enum{
        
        /**
         @brief The mesh geometry is cubic
         */
        cubicInertia,
        
        /**
         @brief The mesh geometry is spherical
         */
        sphericalInertia,
        
        /**
         @brief The mesh geometry is cylindrical
         */
        cylindricalInertia
        
    }INERTIATENSORTYPE;
    
    /**
     @brief The GAMEPADELEMENT enum holds information about the elements of a game pad
     */
    typedef enum{
        
        padButtonA,
        padButtonB,
        padButtonX,
        padButtonY,
        padLeftThumbstick,
        padRightThumbstick,
        padLeftTrigger,
        padRightTrigger,
        padLeftShoulder,
        padRightShoulder,
        padDPadUpButton,
        padDPadDownButton,
        padDPadLeftButton,
        padDPadRightButton
        
    }GAMEPADELEMENT;
    
    /**
     @brief The GAMEPADACTION enum holds information about the action of the element of a game pad
     */
    typedef enum{
        
        padButtonPressed,
        padButtonReleased,
        padThumbstickMoved,
        padThumbstickReleased,
        
    }GAMEPADACTION;
    
    /**
     @brief The DEVICEOSTYPE enum holds information about the current OS target
     */
    typedef enum{
        
        deviceOSIOS,
        deviceOSMACX
        
    }DEVICEOSTYPE;
    
    /**
     @brief The KEYBOARDELEMENT enum holds information about the elements of a keyboard
     */
    typedef enum{
        
        macArrowKey,
        macKeyA,
        macKeyD,
        macKeyW,
        macKeyS,
        macKey1,
        macKey2,
        macKey3,
        macKey4,
        macShiftKey,
        macSpaceKey
        
    }KEYBOARDELEMENT;
    
    /**
     @brief The KEYBOARDACTION enum holds information about the action of the element of a key
     */
    typedef enum{
        
        macKeyPressed,
        macKeyReleased,
        macArrowKeyActive,
        macArrowKeyReleased
        
    }KEYBOARDACTION;
    
    /**
     @brief The MOUSEELEMENT enum holds information about the elements of a mouse
     */
    typedef enum{
        
        mouseLeftButton,
        mouseRightButton,
        mouseCursor
        
    }MOUSEELEMENT;
    
    /**
     @brief The KEYBOARDACTION enum holds information about the action of the element of a mouse
     */
    typedef enum{
        
        mouseButtonPressed, 
        mouseButtonDragged,
        mouseButtonReleased,
        mouseCursorMoved,
        mouseCursorExited,
        mouseCursorDeltaMoved
        
    }MOUSEACTION;
    
}




#endif
