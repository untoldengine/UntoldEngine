//
//  U4DDirector.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DDirector__
#define __MVCTemplate__U4DDirector__


#include <iostream>
#include <vector>
#include <iterator>
#include "U4DShaderManager.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DEntity;
class U4DShaderManager;
class U4DScene;
class U4DWorld;
class U4DCharacterManager;
class U4DData;
class U4DTouches;
class U4DGameModelInterface;
class U4DVector2n;
class U4DControllerInterface;
class U4DTouches;
class U4DLights;
}

namespace U4DEngine {
    
/**
 *  U4DDirector- This class is GOD. It controls the world and the universe of the game. It is in charge of loading the shaders, updating and drawing.
 *  This class is a singleton.
 */

class U4DDirector{
  
private:
    
    
    /**
     *  Current Universe of the game
     */
    U4DScene *scene;
    
    /**
     *  Current Shader Manager. The shader manager is in charge of loading and compiling the shaders
     */
    U4DShaderManager shaderManager;
    
    float displayWidth;
    
    float displayHeight;
    
    std::vector<GLuint> shaderProgram;
    
    U4DLights* mainLight;
    
    //time step accumulator
    float accumulator;
    
protected:
    
    /**
     *  Director Constructor
     */
    U4DDirector();
    
    /**
     *  Director Destructor
     */
    ~U4DDirector();
    
    /**
     *  Copy constructor
     */
    U4DDirector(const U4DDirector& value);

    /**
     *  Copy constructor
     */
    U4DDirector& operator=(const U4DDirector& value);
    
public:
    
    /**
     *  Instance for U4DDirector Singleton
     */
    static U4DDirector* instance;
    
    /**
     *  SharedInstance for U4DDirector Singleton
     */
    static U4DDirector* sharedInstance();
    
    /**
     *  Draw object
     */
    void draw();
    
    /**
     *  Update
     *
     *  @param dt time update
     */
    void update(double dt);
    
    /**
     *  Init
     */
    void init();
    
    /**
     *  Load the openGL shaders
     */
    void loadShaders();
    
    
    /**
     *  Set game universe
     *
     *  @param uUniverse Universe
     */
    void setScene(U4DScene *uScene);
    
    
    //loading shaders
    /**
     *  Add openGL shader program
     *
     *  @param uShaderValue shader program int value
     */
    void addShaderProgram(GLuint uShaderValue);
    
    /**
     *  Get shader program
     *
     *  @param uShader shader name
     *
     *  @return shader program int value
     */
    GLuint getShaderProgram(std::string uShader);

    //set display widht and height;
    
    /**
     *  Set display width and height
     *
     *  @param uWidth  display width
     *  @param uHeight display height
     */
    void setDisplayWidthHeight(float uWidth,float uHeight);
    
    /**
     *  Get display height
     *
     *  @return display height
     */
    float getDisplayHeight();
    
    /**
     *  Get display width
     *
     *  @return display width
     */
    float getDisplayWidth();
    
    
    /**
     *  convert screen point to opengl point
     *
     *  @param xPoint x-coordinate point
     *  @param yPoint y-coordinate point
     *
     *  @return Vector2N point
     */
    U4DVector2n pointToOpenGL(float xPoint,float yPoint);
    
    void touchBegan(const U4DTouches &touches);
    void touchEnded(const U4DTouches &touches);
    void touchMoved(const U4DTouches &touches);
    
    //light
    void loadLight(U4DLights* uLight);
    U4DLights* getLight();
};

}

#endif /* defined(__MVCTemplate__U4DDirector__) */
