//
//  U4DGameModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DGameModel__
#define __UntoldEngine__U4DGameModel__

#include <iostream>
#include "U4DGameModelInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DTouches;
class U4DWorld;
}

namespace U4DEngine {
    
class U4DGameModel:public U4DGameModelInterface{
  
public:
    U4DGameModel(){};
    ~U4DGameModel(){};
    
    virtual void update(double dt){};
    virtual void init(){};
    
    void subscribe(U4DWorld* uGameWorld);
    void subscribe(U4DControllerInterface *uGameController);
    
    void setGameObjectManager(U4DEntityManager *uGameObjectManager);
    
    void notify(U4DWorld *uGameWorld);
    void notify(U4DControllerInterface *uGameController);
    
private:
    
};
    
}
#endif /* defined(__UntoldEngine__U4DGameModel__) */
