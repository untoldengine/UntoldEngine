//
//  U4DField.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DField_hpp
#define U4DField_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DAABB.h"
#include "U4DPlayer.h"

namespace U4DEngine {

class U4DField:public U4DModel {

private:
    
    
public:
    
    U4DField();
    
    ~U4DField();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void shadeField(U4DPlayer *uPlayer);
    
    U4DAABB getFieldAABB();
    
};

}

#endif /* U4DField_hpp */
