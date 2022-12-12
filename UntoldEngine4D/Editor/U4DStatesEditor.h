//
//  U4DStatesEditor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DStatesEditor_hpp
#define U4DStatesEditor_hpp

#include <stdio.h>
#include "U4DEditorStateInterface.h"

namespace U4DEngine {

    class U4DStatesEditor:public U4DEditorStateInterface {
    
    private:
        
        static U4DStatesEditor* instance;
        
    protected:
        
        U4DStatesEditor();
        ~U4DStatesEditor();
        
    public:
        
    
        static U4DStatesEditor* sharedInstance();
        
        void enter(U4DEditor *uEditor);
        
        void execute(U4DEditor *uEditor);
        
        void exit(U4DEditor *uEditor);
        
    };

}
#endif /* U4DStatesEditor_hpp */
