//
//  U4DSceneManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneManager_hpp
#define U4DSceneManager_hpp

#include <stdio.h>
#include "U4DScene.h"


namespace U4DEngine {

    /**
    @ingroup scene
    @brief The U4DSceneManager class is in charge of managing the current scene enabled.
    */
    class U4DSceneManager {
        
    private:
        
        /**
        @brief current active scene
        */
        U4DScene *currentScene;
        
        /**
        @brief scene requested to render
        */
        U4DScene *sceneToChange;
        
        /**
        @brief Pointer to the game controller
        */
        U4DControllerInterface *controllerInput;
        
        /**
        @brief Instace for the U4DSceneManager singleton
        */
        static U4DSceneManager* instance;
        
        /**
        @brief Request to change scene
        */
        bool requestToChangeScene;

    protected:
        
        /**
        @brief Scene Manager constructor
        */
        U4DSceneManager();
        
        /**
        @brief Scene Manager destructor
        */
        ~U4DSceneManager();
        
    public:
        
        /**
        @brief Method which returns an instace of the U4DSceneManager singleton
        
        @return instance of the U4DSceneManager singleton
        */
        static U4DSceneManager* sharedInstance();
        
        /**
        @brief Changes scene when it is safe to do so
        */
        void isSafeToChangeScene();
        
        /**
        @brief Changes scene to new scene
        
        @param uScene scene to change to
        */
        void changeScene(U4DScene *uScene);
        
        /**
        @brief Returns the current scene
        */
        U4DScene *getCurrentScene();
        
        /**
        @brief Pointer to the game controller
        */
        U4DControllerInterface *getGameController();
        
        /**
        @brief sets request to change to new scene
         
        @param uValue true if the request happened
        */
        void setRequestToChangeScene(bool uValue);
        
        /**
        @brief true if a request to change the scene occurred
        */
        bool getRequestToChangeScene();

    };

}

#endif /* U4DSceneManager_hpp */
