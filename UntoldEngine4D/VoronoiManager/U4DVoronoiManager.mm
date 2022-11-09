//
//  U4DVoronoiManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/28/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DVoronoiManager.h"
#include <cmath>
#include "U4DMatchManager.h"
#include "U4DGameConfigs.h"
#include "U4DPlayer.h"
#include "U4DTeam.h"
#include "U4DVector3n.h"
#include "U4DNumerical.h"
#include "U4DVector2n.h"

namespace U4DEngine {

U4DVoronoiManager *U4DVoronoiManager::instance=nullptr;

U4DVoronoiManager::U4DVoronoiManager(){
        
    }

U4DVoronoiManager::~U4DVoronoiManager(){
        
    }

U4DVoronoiManager *U4DVoronoiManager::sharedInstance(){
    
    if (instance==nullptr) {
        
        instance=new U4DVoronoiManager();
        
    }
    
    return instance;
}

void U4DVoronoiManager::computeFortuneAlgorithm(){
    
    U4DMatchManager *matchManager=U4DMatchManager::sharedInstance();
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();

    float fieldHalfWidth=gameConfigs->getParameterForKey("fieldHalfWidth");
    float fieldHalfLength=gameConfigs->getParameterForKey("fieldHalfLength");
    
    U4DVector2n rangeFrom=U4DVector2n(-1.0,1.0);
    U4DVector2n rangeTo=U4DVector2n(0.0,1.0);
    
    U4DNumerical numerical;
    
    std::vector<mygal::Vector2<double>> points;
    
    int index=0;
    
    for(auto &n:matchManager->teamA->getPlayers()){
        
        mygal::Vector2<double> point;
        
        //Update player position
        U4DVector3n pos=n->getAbsolutePosition();

        pos.z/=fieldHalfWidth;
        pos.x/=fieldHalfLength;
        
        pos.z=numerical.remapValue(pos.z,rangeFrom,rangeTo);
        pos.x=numerical.remapValue(pos.x,rangeFrom,rangeTo);
        
        point.x=pos.x;
        point.y=pos.z;
        
        //link player to site
        playerIndexMap.insert(std::pair<int,U4DPlayer*>(index, n));
        //add point
        points.push_back(point);
        index++;
    }
    
    for(const auto &n:matchManager->teamB->getPlayers()){
        
        mygal::Vector2<double> point;
        
        //Update player position
        U4DVector3n pos=n->getAbsolutePosition();

        pos.z/=fieldHalfWidth;
        pos.x/=fieldHalfLength;
        
        pos.z=numerical.remapValue(pos.z,rangeFrom,rangeTo);
        pos.x=numerical.remapValue(pos.x,rangeFrom,rangeTo);
        
        point.x=pos.x;
        point.y=pos.z;
        
        //link player to site
        playerIndexMap.insert(std::pair<int,U4DPlayer*>(index, n));
        points.push_back(point);
        
        index++;
    }
    
    // Initialize an instance of Fortune's algorithm
    auto algorithm = mygal::FortuneAlgorithm<double>(points);
    
    //construct the diagram
    algorithm.construct();
    
    //Bound the diagram
    algorithm.bound(mygal::Box<double>{-0.05, -0.05, 1.05, 1.05});
    
    //get the constructed diagram
    diagram=algorithm.getDiagram();
    
    //Compute the intersetion between the diagram and a box
    diagram.intersect(mygal::Box<double>{0.0,0.0,1.0,1.0});
    
    triangulation = diagram.computeTriangulation();
    getNeighbors(6);
}

std::vector<U4DSegment> U4DVoronoiManager::getVoronoiSegments(){
    
    std::vector<U4DSegment> segments;
    auto halfEdgesDiagramList=diagram.getHalfEdges();
    
    for(auto const& n:halfEdgesDiagramList){
        
        auto originVertex=n.origin;
        auto destinationVertex=n.destination;
        
        U4DPoint3n pointA(originVertex->point.x,originVertex->point.y,0.0);
        U4DPoint3n pointB(destinationVertex->point.x,destinationVertex->point.y,0.0);
        
        U4DSegment segment(pointA,pointB);
        segments.push_back(segment);
        
    }
    
    return segments;
}

float U4DVoronoiManager::computeSiteArea(int uIndex){
    
    auto site=diagram.getSite(uIndex);
    auto face=site->face;
    
    auto siteOrigin=site->point;
    U4DPoint3n sitePoint(siteOrigin.x,siteOrigin.y,0.0);
    auto *temp=face->outerComponent;
    float area=0;
    
    if(face->outerComponent!=nullptr){
        
        do{
            //get temp origin and destination
            auto origin=temp->origin->point;
            auto destination=temp->destination->point;
            
            U4DPoint3n originPoint(origin.x,origin.y,0.0);
            U4DPoint3n destinationPoint(destination.x,destination.y,0.0);
            
            //get the length between origin & destination
            float a=originPoint.distanceBetweenPoints(destinationPoint);
            
            //get the length between origin and site
            float b=originPoint.distanceBetweenPoints(sitePoint);
            
            //get the length between destination and siteOrigin
            float c=destinationPoint.distanceBetweenPoints(sitePoint);
            
            //find semiperimeter
            float s=(a+b+c)/2;
            
            area+=sqrt(s*(s-a)*(s-b)*(s-c));
            
            temp=temp->next;
        }while(temp!=face->outerComponent);
        
        
    }
    
    return area;
    
}

void U4DVoronoiManager::computeAreas(){
    float totalArea=0;
    auto faces=diagram.getFaces();
    
    for(auto const &n:faces){
        
        auto site=n.site;
        auto siteOrigin=site->point;
        U4DPoint3n sitePoint(siteOrigin.x,siteOrigin.y,0.0);
        auto *temp=n.outerComponent;
        float area=0;
        
        if(n.outerComponent!=nullptr){
            
            do{
                //get temp origin and destination
                auto origin=temp->origin->point;
                auto destination=temp->destination->point;
                
                U4DPoint3n originPoint(origin.x,origin.y,0.0);
                U4DPoint3n destinationPoint(destination.x,destination.y,0.0);
                
                //get the length between origin & destination
                float a=originPoint.distanceBetweenPoints(destinationPoint);
                
                //get the length between origin and site
                float b=originPoint.distanceBetweenPoints(sitePoint);
                
                //get the length between destination and siteOrigin
                float c=destinationPoint.distanceBetweenPoints(sitePoint);
                
                //find semiperimeter
                float s=(a+b+c)/2;
                
                area+=sqrt(s*(s-a)*(s-b)*(s-c));
                
                temp=temp->next;
            }while(temp!=n.outerComponent);
            
            
        }
        totalArea+=area;
        std::cout<<"Site: "<<site->index<<"Player: "<<getPlayerAtIndex(site->index)->getName()<<" area: "<<area<<std::endl;
    }
    
    std::cout<<"Total Area: "<<totalArea<<std::endl;
}

U4DPlayer *U4DVoronoiManager::getPlayerAtIndex(int uIndex){
    
    std::map<int,U4DPlayer*>::iterator it=playerIndexMap.find(uIndex);
    U4DPlayer* player=nullptr;
    
    if (it != playerIndexMap.end()) {
        player=playerIndexMap.find(uIndex)->second;
    }
    
    return player;
}

std::vector<U4DPlayer*> U4DVoronoiManager::getNeighbors(int uIndex){
    
    U4DPlayer* player=getPlayerAtIndex(uIndex);
    U4DTeam *team=player->getTeam();
    std::vector<U4DPlayer*> teammates;
    
    std::vector<std::size_t> neighbors=triangulation.getNeighbors(uIndex);
    
    for(auto n:neighbors){
    
        U4DPlayer* teammate=getPlayerAtIndex(n);
        U4DTeam *teammateTeam=teammate->getTeam();
        
        if(team==teammateTeam){
            teammates.push_back(teammate);
            
        }
    }
    
    return teammates;
}

U4DPlayer* U4DVoronoiManager::getNeighborWithOptimalSpace(int uIndex){
    
    U4DPlayer* playerWithOptimalSpace=nullptr;
    float area=FLT_MIN;
    U4DPlayer* player=getPlayerAtIndex(uIndex);
    U4DTeam *team=player->getTeam();
    
    
    std::vector<std::size_t> neighbors=triangulation.getNeighbors(uIndex);
    
    for(auto n:neighbors){
    
        U4DPlayer* teammate=getPlayerAtIndex(n);
        U4DTeam *teammateTeam=teammate->getTeam();
        
        if(team==teammateTeam){
            float newArea=computeSiteArea(n);
            if (newArea>area) {
                area=newArea;
                playerWithOptimalSpace=teammate;
            }
            
        }
    }
    
    return playerWithOptimalSpace;
}

}

