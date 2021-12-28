//
//  U4DNetworkManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DNetworkManager.h"
#include "U4DLogger.h"
#include "U4DOutMemoryStream.h"
#include "U4DInMemoryStream.h"
#include <cstring>

namespace U4DEngine {

    U4DNetworkManager* U4DNetworkManager::instance=0;

    U4DNetworkManager::U4DNetworkManager(){
            
            
            
        }

    U4DNetworkManager::~U4DNetworkManager(){
            
        }

    U4DNetworkManager* U4DNetworkManager::sharedInstance(){
            
        if (instance==0) {
            instance=new U4DNetworkManager();
            
        }
        
        return instance;
    }

    bool U4DNetworkManager::initializeNetwork(){
        
        if(enet_initialize()!=0){
            fprintf(stderr, "An error occurred while initilizing enet");
            return false;
        }
        
        client=enet_host_create(NULL,1,1,0,0);

        if (client==NULL) {
            fprintf(stderr,"An error occurred while trying to create an Enet client host");
            return false;
        }
        
        return true;
    }

    bool U4DNetworkManager::connect(const char *uIPAdress, int uPort){
        
        if(initializeNetwork()){
            
            ENetEvent event; //events we are receiving from the server
            enet_address_set_host(&address, uIPAdress);
            address.port=uPort;
            peer=enet_host_connect(client, &address, 1, 0);
            
            if (peer==NULL) {
                fprintf(stderr, "No available peers for initiating an Enet connection");
                return false;
            }

            //returns number of events received
            if(enet_host_service(client, &event, 5000)>0 && event.type==ENET_EVENT_TYPE_CONNECT){
                
                U4DLogger *logger=U4DLogger::sharedInstance();
                logger->log("Connection to %s:%u succedded",uIPAdress,uPort);
                return true;
                
            }else{
                enet_peer_reset(peer);
                U4DLogger *logger=U4DLogger::sharedInstance();
                logger->log("Connection to %s:%u failed",uIPAdress,uPort);
                
                //you can loop back to a menu but for now we just return exit_success
                return false;
            }
            
        }
        
        return false;
    }

    void U4DNetworkManager::receiveMsg(){
        
        ENetEvent event; //events we are receiving from the server
        
        while (enet_host_service(client, &event, 0)>0) {
            switch (event.type) {
                case ENET_EVENT_TYPE_RECEIVE:
//                    printf ("A packet of length %zuu containing %s was received from %x:%u on channel %u.\n",
//                            event.packet->dataLength,
//                            event.packet->data,
//                            event.peer->address.host,
//                            event.peer->address.port,event.channelID);
                    
                    receivePacket(event);
                    
                    enet_packet_destroy(event.packet);

                    break;

                default:
                    break;
            }
        }
    }

    void U4DNetworkManager::receivePacket(ENetEvent uEvent){
        
        U4DInMemoryStream inStream((char*)uEvent.packet->data,static_cast<u_int32_t>(uEvent.packet->dataLength));
        
        char name[10];
        int networkID;
        
        inStream.read(name,10);
        inStream.read(networkID);
        
        std::cout<<"Name of player: "<<name<<" NetworkID is: "<<networkID<<std::endl;
        
        
    }

    void U4DNetworkManager::sendPacket(U4DPlayer *uPlayer){
        
        U4DOutMemoryStream outStream;
        char name[10];
        strcpy(name,uPlayer->getName().c_str());
        outStream.write(name,10);
        
        u_int32_t networkID=3;
        outStream.write(networkID);
        
        ENetPacket *packet=enet_packet_create(outStream.getBufferPtr(), outStream.getLength(), ENET_PACKET_FLAG_RELIABLE);
        enet_peer_send(peer,0,packet);
        
    }

}
