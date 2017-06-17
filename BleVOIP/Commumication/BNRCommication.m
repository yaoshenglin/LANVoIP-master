//
//  BNRCommication.m
//  Game
//
//  Created by JustinYang on 15/9/21.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import "BNRCommication.h"

@interface BNRCommication ()<MCSessionDelegate>
@property (nonatomic,strong) MCPeerID *localPeerID;
@end

@implementation BNRCommication


NSString * const kServerName         =       @"VOIP";


- (MCPeerID *)localPeerID
{
    if (!_localPeerID) {
        _localPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    }
    return _localPeerID;
}

- (MCSession *)session
{
    if (!_session) {
        _session = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        /**
         *  忽略这个警告，他的子类已经实现了MCSessionDelegate协议
         */
        _session.delegate = self;
    }
    return _session;
}

- (void)sendData:(NSData *)data
{
    if(self.session.connectedPeers.count == 0)
    {
        return;
    }
    NSError *err;
    [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:&err];
    if (err) {
        NSLog(@"there is error translate to data ");
        if ([self.delegate respondsToSelector:@selector(commication:sendDicFail:)]) {
            [self.delegate commication:self sendDicFail:err];
        }
    }
}

#pragma mark - --------MCSessionDelegate------------------------
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    //会话状态发生改变
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    //从会话中接收到数据
}

// Received a byte stream from remote peer.
- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID
{
    
}

// Start receiving a resource from remote peer.
- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress
{
    
}

// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
- (void)                    session:(MCSession *)session
 didFinishReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                              atURL:(NSURL *)localURL
                          withError:(nullable NSError *)error
{
    
}

@end
