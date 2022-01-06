//
//  U4DClientManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DClientManager.h"
#include "U4DLogger.h"
#include "Constants.h"
#include "U4DOutMemoryStream.h"
#include "U4DInMemoryStream.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include <string.h>
#include <cstring>

namespace U4DEngine {

    U4DClientManager* U4DClientManager::instance=0;

    U4DClientManager::U4DClientManager():isConnected(false){
            
        
        }

    U4DClientManager::~U4DClientManager(){
            
        }

    U4DClientManager* U4DClientManager::sharedInstance(){
            
        if (instance==0) {
            instance=new U4DClientManager();
            
        }
        
        return instance;
    }

   

    void U4DClientManager::joinGameAtServer(const char *uIPAddress, int uPort){
        
        ipAddress=uIPAddress;
        port=uPort;
        
        //change state to connect
        changeState(clientConnect);
        
    }

    void U4DClientManager::update(double dt){
        
    }

    void U4DClientManager::changeState(int uState){

        switch (uState) {
                
            case clientConnect:
                //connect
                connectToServer();
                
                break;
                
            case clientJoinAttempt:
                
                //attempt to join the game
                attemptToJoinGame();
                
                break;
                
            case clientJoin:
                
                
                break;
                
            case clientReplicatingData:
                
                break;
                
            default:
                break;
        }
    
    }

    void U4DClientManager::connectToServer(){
        
        if(enet_initialize()!=0){
            fprintf(stderr, "An error occurred while initilizing enet");
            changeState(clientConnectFailed);
        }
        
        client=enet_host_create(NULL,1,1,0,0);

        if (client==NULL) {
            fprintf(stderr,"An error occurred while trying to create an Enet client host");
            
            changeState(clientConnectFailed);
        }
        
        
        enet_address_set_host(&address, ipAddress);
        address.port=port;
        
        peer=enet_host_connect(client, &address, 1, 0);
        
        if (peer==NULL) {
            fprintf(stderr, "No available peers for initiating an Enet connection");
            
            changeState(clientConnectFailed);
        }
        
        ENetEvent event; //events we are receiving from the server
        
        //returns number of events received
        if(enet_host_service(client, &event, 5000)>0 && event.type==ENET_EVENT_TYPE_CONNECT){
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            logger->log("Connection to %s:%u succedded",ipAddress,port);
            isConnected=true;
            
            changeState(clientJoinAttempt);
            
        }else{
            enet_peer_reset(peer);
            U4DLogger *logger=U4DLogger::sharedInstance();
            logger->log("Connection to %s:%u failed",ipAddress,port);
            
            //you can loop back to a menu but for now we just return exit_success
            changeState(clientConnectFailed);
        }
    }

    void U4DClientManager::attemptToJoinGame(){
        
        U4DOutMemoryStream outStream;
        
        outStream.write(ptJoinAttempt);
        
        //send info about the game objects
        //send game object name
        char clientName[U4DEngine::maxClientStringNameSize];
        
        strcpy(clientName,"harold");
        outStream.write(clientName,U4DEngine::maxClientStringNameSize);
        
        //traverse the world and provide player instance
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        U4DEntity *child=world;
        int modelCount=0;
        
        while(child!=nullptr){
            
            if (child->getEntityType()==U4DEngine::MODEL) {
                modelCount++;
            }
            
            child=child->next;
        }
        
        //write the model count
        outStream.write(modelCount);
        
        child=world;
        
        while (child!=nullptr) {
            
            if (child->getEntityType()==U4DEngine::MODEL) {
                    
                U4DModel *model=dynamic_cast<U4DModel*>(child);
                
                outStream.write(model->getEntityId());
                
                char classType[U4DEngine::maxClientStringNameSize];
                strcpy(classType, model->getClassType().c_str());
                outStream.write(classType, U4DEngine::maxClientStringNameSize);
                
            }
            
            child=child->next;
            
        }
        
        
        sendPacket(outStream);
        
    }

    void U4DClientManager::processJoinedPacket(U4DInMemoryStream &uInStream){
        
        int playerId=0;
        uInStream.read(playerId);
        
        int gameObjectsCount=0;
        uInStream.read(gameObjectsCount);
        
        for(int i=0;i<gameObjectsCount;i++){
            
            int gameObjectId;
            u_int32_t gameObjectNetworkId;
            char classType[U4DEngine::maxClientStringNameSize];
            
            uInStream.read(gameObjectId);
            uInStream.read(gameObjectNetworkId);
            uInStream.read(classType,U4DEngine::maxClientStringNameSize);
            
            //link gameId to Network Id
            linkingContext.linkClientModelDataToNetworkId(gameObjectId,classType,gameObjectNetworkId);
            
            std::cout<<"Game Object id: "<<gameObjectId<<" Network Id: "<<gameObjectNetworkId<<" classtype: "<<classType<<std::endl;
        }
        
        changeState(clientJoin);
    }

    void U4DClientManager::messageLoop(){
        
        ENetEvent event; //events we are receiving from the server
        
        while (enet_host_service(client, &event, 0)>0) {
            switch (event.type) {
                case ENET_EVENT_TYPE_RECEIVE:
                {
//                    printf ("A packet of length %zuu containing %s was received from %x:%u on channel %u.\n",
//                            event.packet->dataLength,
//                            event.packet->data,
//                            event.peer->address.host,
//                            event.peer->address.port,event.channelID);
                    
                    U4DInMemoryStream inStream((char*)event.packet->data,static_cast<u_int32_t>(event.packet->dataLength));
                    
                    processPacket(inStream);
                    
                    enet_packet_destroy(event.packet);
                }
                    break;

                default:
                    break;
            }
        }
    }

    void U4DClientManager::processPacket(U4DInMemoryStream &uInStream){
        
        //char name[10];
        int packetType;
        
        //inStream.read(name,10);
        uInStream.read(packetType);
        
        switch (packetType) {
            
            case U4DEngine::ptConnect:
                
                break;
                
            case U4DEngine::ptJoinAttempt:
                
               
                
                break;
            
            case U4DEngine::ptJoined:

                //Need to read ID and any other info regarding the game
                
                processJoinedPacket(uInStream);
                
                
                
                break;
                
            case U4DEngine::ptReplicationData:
                
                break;
                
            default:
                break;
        }
        
    }

    void U4DClientManager::sendPacket(U4DOutMemoryStream &uOutStream){
        
//        if(uPlayer!=nullptr){
//            U4DOutMemoryStream outStream;
//    //        char name[10];
//    //        strcpy(name,uPlayer->getName().c_str());
//    //        outStream.write(name,10);
//
//            int packetType=U4DEngine::ptReplicationData;
//            u_int32_t networkID=networkId;
//
//            char classId[10];
//            strcpy(classId,uPlayer->getClassType().c_str());
//
//            char currentState[20];
//            strcpy(currentState,uPlayer->getCurrentStateName().c_str());
//
//            U4DVector3n dribblingDirection=uPlayer->dribblingDirection;
//
//            outStream.write(packetType);
//            outStream.write(networkID);
//            outStream.write(classId,10);
//            outStream.write(currentState,20);
//            outStream.write(dribblingDirection.x);
//            outStream.write(dribblingDirection.y);
//            outStream.write(dribblingDirection.z);
//
//            ENetPacket *packet=enet_packet_create(outStream.getBufferPtr(), outStream.getLength(), ENET_PACKET_FLAG_RELIABLE);
//            enet_peer_send(peer,0,packet);
//        }
        
        ENetPacket *packet=enet_packet_create(uOutStream.getBufferPtr(), uOutStream.getLength(), ENET_PACKET_FLAG_RELIABLE);
        enet_peer_send(peer,0,packet);
    }

    bool U4DClientManager::isConnectedToServer(){
        return isConnected;
    }

}
