//
//  U4DNodeEditor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/6/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DNodeEditor.h"
#include <iostream>
namespace U4DEngine {

U4DNodeEditor *U4DNodeEditor::instance=0;

U4DNodeEditor* U4DNodeEditor::sharedInstance(){
    
    if(instance==0){
        instance=new U4DNodeEditor();
    }
    
    return instance;
}

U4DNodeEditor::U4DNodeEditor(){
    
    initializeNodeEditor();
}

U4DNodeEditor::~U4DNodeEditor(){
    
}

void U4DNodeEditor::showEditor(){
    
    ImNodes::EditorContextSet(editor.context);

    ImGui::Begin("Node Editor");
    ImGui::TextUnformatted("Editor");

    ImNodes::BeginNodeEditor();
    auto gio = ImGui::GetIO();

    if (ImGui::IsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows) &&
        ImNodes::IsEditorHovered() && ImGui::IsKeyReleased(gio.KeyMap[ImGuiKey_A]))
    {
        const int node_id = ++editor.current_id;
        ImNodes::SetNodeScreenSpacePos(node_id, ImGui::GetMousePos());
        ImNodes::SnapNodeToGrid(node_id);
        editor.nodes.push_back(Node(node_id, 0.f));
    }

    for (Node& node : editor.nodes)
    {
        ImNodes::BeginNode(node.id);

        ImNodes::BeginNodeTitleBar();
        ImGui::TextUnformatted("state");
        ImNodes::EndNodeTitleBar();
        
        ImNodes::BeginInputAttribute(node.id << 8);
        ImGui::TextUnformatted("input");
        ImNodes::EndInputAttribute();

//        ImNodes::BeginStaticAttribute(node.id << 16);
//        ImGui::PushItemWidth(80.0f);
//        ImGui::DragFloat("value", &node.value, 0.01f);
//        ImGui::PopItemWidth();
//        ImNodes::EndStaticAttribute();

        ImNodes::BeginOutputAttribute(node.id << 16);
        const float text_width = ImGui::CalcTextSize("output").x;
        ImGui::Indent(80.f + ImGui::CalcTextSize("value").x - text_width);
        ImGui::TextUnformatted("output");
        ImNodes::EndOutputAttribute();
        
        ImNodes::BeginOutputAttribute(node.id << 24);
        const float text_width2 = ImGui::CalcTextSize("output").x;
        ImGui::Indent(80.f + ImGui::CalcTextSize("value").x - text_width2);
        ImGui::TextUnformatted("output2");
        ImNodes::EndOutputAttribute();

        ImNodes::EndNode();
    }
    
    for (const Link& link : editor.links)
    {
        ImNodes::Link(link.id, link.start_attr, link.end_attr);
    }

    ImNodes::EndNodeEditor();

    {
        Link link;
        if (ImNodes::IsLinkCreated(&link.start_attr, &link.end_attr))
        {
            link.id = ++editor.current_id;
            editor.links.push_back(link);
            
            std::cout<<"links: "<<link.start_attr<<"->"<<link.end_attr<<std::endl;
            
        }
    }

    {
        int link_id;
        if (ImNodes::IsLinkDestroyed(&link_id))
        {
            auto iter = std::find_if(
                editor.links.begin(), editor.links.end(), [link_id](const Link& link) -> bool {
                    return link.id == link_id;
                });
            assert(iter != editor.links.end());
            editor.links.erase(iter);
        }
    }

    ImGui::End();
}

void U4DNodeEditor::initializeNodeEditor(){
    
    editor.context = ImNodes::EditorContextCreate();

    ImNodes::PushAttributeFlag(ImNodesAttributeFlags_EnableLinkDetachWithDragClick);

    ImNodesIO& io = ImNodes::GetIO();
    io.LinkDetachWithModifierClick.Modifier = &ImGui::GetIO().KeyCtrl;
    io.MultipleSelectModifier.Modifier = &ImGui::GetIO().KeyCtrl;

    ImNodesStyle& style = ImNodes::GetStyle();
    style.Flags |= ImNodesStyleFlags_GridLinesPrimary | ImNodesStyleFlags_GridSnapping;
}



}
