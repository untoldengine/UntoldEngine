//
//  U4DEditorStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/26/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DEditorStateInterface_hpp
#define U4DEditorStateInterface_hpp

#include <stdio.h>
#include <string>
#include "U4DEditor.h"

namespace U4DEngine {

class U4DEditorStateInterface {
    
public:
    std::string name;
    
    virtual ~U4DEditorStateInterface(){};
    
    virtual void enter(U4DEditor *uEditor)=0;
    
    virtual void execute(U4DEditor *uEditor)=0;
    
    virtual void exit(U4DEditor *uEditor)=0;
};

}

#endif /* U4DEditorStateInterface_hpp */
