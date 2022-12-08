//
//  U4DEditorStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/26/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DEditorStateManager_hpp
#define U4DEditorStateManager_hpp

#include <stdio.h>

namespace U4DEngine {

class U4DEditor;
class U4DEditorStateInterface;

class U4DEditorStateManager {
    
private:
    
    U4DEditor *editor;
    
    U4DEditorStateInterface *previousState;
    
    U4DEditorStateInterface *currentState;
    
public:
    
    U4DEditorStateManager(U4DEditor *uEditor);
    
    ~U4DEditorStateManager();
    
    void showEditor();
    
    void changeState(U4DEditorStateInterface *uState);
    
    U4DEditorStateInterface *getCurrentState();
    
    U4DEditorStateInterface *getPreviousState();
    
};

}

#endif /* U4DEditorStateManager_hpp */
