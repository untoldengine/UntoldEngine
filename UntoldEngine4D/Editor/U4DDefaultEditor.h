//
//  U4DDefaultEditor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/24/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DDefaultEditor_hpp
#define U4DDefaultEditor_hpp

#include <stdio.h>
#include "U4DEditorStateInterface.h"

namespace U4DEngine {

    class U4DDefaultEditor:public U4DEditorStateInterface {
    
    private:
        
        static U4DDefaultEditor* instance;
        
    protected:
        
        U4DDefaultEditor();
        ~U4DDefaultEditor();
        
    public:
        
    
        static U4DDefaultEditor* sharedInstance();
        
        void enter(U4DEditor *uEditor);
        
        void execute(U4DEditor *uEditor);
        
        void exit(U4DEditor *uEditor);
        
    };

}

#endif /* U4DDefaultEditor_hpp */
