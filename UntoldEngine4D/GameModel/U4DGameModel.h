//
//  U4DGameModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DGameModel__
#define __UntoldEngine__U4DGameModel__

#include <iostream>
#include "U4DGameModelInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DWorld;
}

namespace U4DEngine {
    
class U4DGameModel:public U4DGameModelInterface{
  
private:
    
    U4DWorld *gameWorld;
    U4DControllerInterface *gameController;
    U4DEntityManager *gameEntityManager;

public:
    U4DGameModel(){};
    
    ~U4DGameModel(){};
    
    virtual void update(double dt){};
    
    virtual void init(){};
    
    void setGameEntityManager(U4DEntityManager *uGameEntityManager);
    
    void setGameWorld(U4DWorld *uGameWorld);
    void setGameController(U4DControllerInterface *uGameController);
    
    U4DWorld* getGameWorld();
    U4DControllerInterface* getGameController();
    U4DEntityManager* getGameEntityManager();
    
    void notify(U4DWorld *uGameWorld);
    void notify(U4DControllerInterface *uGameController);
    
    U4DEntity* searchChild(std::string uName);
    
    virtual void receiveUserInputUpdate(void *uData){};
    
};
    
}
#endif /* defined(__UntoldEngine__U4DGameModel__) */
