//
//  U4DGameController.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/6/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGameController_hpp
#define U4DGameController_hpp

#include <stdio.h>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

#import <GameController/GameController.h>

namespace U4DEngine {
    
    class U4DInputElement;
    class U4DLayer;

}

namespace U4DEngine {

    class U4DGameController:public U4DControllerInterface {
        
    private:
        
        //input element container
        std::vector<U4DInputElement*> inputElementContainer;
        
    protected:
        
        /**
         * @brief The view component (mvc) linked to the controller
         * @details The view component (MVC) refers to the U4DWorld entity used in the game
         */
        U4DWorld *gameWorld;

        /**
         * @brief the model component (mvc) linked to the controller
         * @details The Model component refers to the U4DGameModel object.
         */
        U4DGameModelInterface *gameModel;

        /**
         * @brief variable to determine if an action was received
         */
        bool receivedAction;
        
    public:
        
        U4DGameController();
        
        ~U4DGameController();
        
        virtual void init(){};
        
        void update(double dt);
        
        void registerInputEntity(U4DInputElement *uInputElement);
        
        void removeInputEntity(U4DInputElement *uInputElement);
        
        void notifyInputEntity();
        
        void changeState(INPUTELEMENTTYPE uInputElementType, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition);
        
        /**
         * @brief Sets the current view component of the game
         * @details The view component (MVC) refers to the U4DWorld entity used in the game
         *
         * @param uGameWorld the U4DWorld entity
         */
        void setGameWorld(U4DWorld *uGameWorld);

        /**
         * @brief Sets the current Model component (MVC) of the game
         * @details The Model component referst to the U4DGameModel object.
         *
         * @param uGameModel the U4DGameModel object
         */
        void setGameModel(U4DGameModelInterface *uGameModel);
        
        /**
         * @brief Gets the current U4DWorld entity linked to the controller
         * @details The U4DWorld entity refers to the view component of the MVC
         * @return The current game world. i.e. view component
         */
        U4DWorld* getGameWorld();

        /**
         * @brief Gets the current U4DGameModel object linked to the controller
         * @details The U4DGameModel refers to the model component of the MVC
         * @return The current Game Model. i.e. game logic
         */
        U4DGameModelInterface* getGameModel();
        
        /**
         * @brief Sends user input to the linked U4DGameModel
         * @details The controller sends the user input information to the U4DGameModel
         *
         * @param uData data containing the informationation about the user input
         */
        void sendUserInputUpdate(void *uData);
        
        /**
         * @brief Indicates that an action on the controller has been received
         * @details Gets set Whenever there is an action on the controller such as a press, release, movement.
         *
         * @param uValue true for action has been detected.
         */
        void setReceivedAction(bool uValue);
        
        virtual void getUserInputData(unichar uCharacter, INPUTELEMENTACTION uInputAction){};
        
        void getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition);
        
        void getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction);
        
        virtual void getUserInputData(GCExtendedGamepad *gamepad, GCControllerElement *element){};
        
    };

}


#endif /* U4DGameController_hpp */
