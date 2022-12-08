//
//  U4DZoneEditor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/25/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DZoneEditor_hpp
#define U4DZoneEditor_hpp

#include <stdio.h>
#include "U4DEditorStateInterface.h"

namespace U4DEngine {

    class U4DZoneEditor:public U4DEditorStateInterface {
    
    private:
        
        static U4DZoneEditor* instance;
        
    protected:
        
        U4DZoneEditor();
        ~U4DZoneEditor();
        
    public:
        
    
        static U4DZoneEditor* sharedInstance();
        
        void enter(U4DEditor *uEditor);
        
        void execute(U4DEditor *uEditor);
        
        void exit(U4DEditor *uEditor);
        
    };

}
#endif /* U4DZoneEditor_hpp */
