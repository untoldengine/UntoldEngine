//
//  U4DNodeEditor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/6/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNodeEditor_hpp
#define U4DNodeEditor_hpp

#include <stdio.h>
#include <vector>
#include "imnodes.h"
#include "imgui.h"

namespace U4DEngine {

struct Node
{
    int   id;
    float value;

    Node(const int i, const float v) : id(i), value(v) {}
};

struct Link
{
    int id;
    int start_attr, end_attr;
};

struct Editor
{
    ImNodesEditorContext* context = nullptr;
    std::vector<Node>     nodes;
    std::vector<Link>     links;
    int                   current_id = 0;
};

class U4DNodeEditor {
    
private:
    
    static U4DNodeEditor *instance;
    
    Editor editor;

protected:
    
    U4DNodeEditor();
    
    ~U4DNodeEditor();
    
public:
    
    static U4DNodeEditor* sharedInstance();
    
    void initializeNodeEditor();
    
    void showEditor();
    
    
};

}


#endif /* U4DNodeEditor_hpp */
