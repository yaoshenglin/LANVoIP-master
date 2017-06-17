//
//  BNRChatRoomVC.m
//  BleVOIP
//  聊天
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import "BNRChatRoomVC.h"
//#import "VoiceConvertHandle.h"
#import "H264HwEncoderImpl.h"
#import "H264HwDecoderImpl.h"
#import "BNRClient.h"
#import "BNRServer.h"
#import "MBProgressHUD.h"
#import "BNVideoData.h"
#import "AAPLEAGLLayer.h"
#import "CTB.h"

@interface BNRChatRoomVC ()<BNRServerDelegate,BNRClientDelegate,H264HwEncoderImplDelegate,H264HwDecoderImplDelegate>
{
    BNVideoData *videoData;
    AAPLEAGLLayer *playLayer;
    
    H264HwEncoderImpl *h264Encoder;
    H264HwDecoderImpl *h264Decoder;
}

@end

@implementation BNRChatRoomVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"开始通话";
    // Do any additional setup after loading the view.
    //[VoiceConvertHandle shareInstance].delegate = self;
    self.manager.delegate = self;
    
    h264Encoder = [H264HwEncoderImpl alloc];
    [h264Encoder initWithConfiguration];
    [h264Encoder initEncode:h264outputWidth height:h264outputHeight];
    h264Encoder.delegate = self;
    
    h264Decoder = [[H264HwDecoderImpl alloc] init];
    h264Decoder.delegate = self;
    
    videoData = [[BNVideoData alloc] init];
    videoData.delegate = self;
    [CTB duration:0.3 block:^{
        [videoData setupCamera];
    }];
    
    CGFloat x = 10;
    playLayer = [[AAPLEAGLLayer alloc] initWithFrame:CGRectMake(10, 220, Screen_Width-x*2, 160)];
    playLayer.backgroundColor = [UIColor clearColor].CGColor;
    [self.view.layer addSublayer:playLayer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)realRecordVoiceHandle:(UIButton *)sender
{
    if ([sender.currentTitle isEqualToString:@"开始通话"]) {
        //[VoiceConvertHandle shareInstance].startRecord = YES;
        [sender setTitle:@"停止通话" forState:UIControlStateNormal];
        [videoData startRunning];
    }else{
        //[VoiceConvertHandle shareInstance].startRecord = NO;
        [sender setTitle:@"开始通话" forState:UIControlStateNormal];
        [videoData stopRunning];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if ([connection isKindOfClass:[AVCaptureConnection class]])
    {
        [h264Encoder encode:sampleBuffer];
    }
}

#pragma mark -  H264编码回调  H264HwEncoderImplDelegate
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    //发sps
    NSMutableData *h264Data = [[NSMutableData alloc] init];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:sps];
    [self covertedData:h264Data];
    //发pps
    [h264Data resetBytesInRange:NSMakeRange(0, [h264Data length])];
    [h264Data setLength:0];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:pps];
    
    [self covertedData:h264Data];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    NSMutableData *h264Data = [[NSMutableData alloc] init];
    [h264Data appendData:ByteHeader];
    [h264Data appendData:data];
    [self covertedData:h264Data];
}

#pragma mark -- BNRClientDelegate
- (void)commication:(id)commicaton didReceiveData:(NSData *)data fromPeerID:(MCPeerID *)peerID
{
    //收到数据
//    [[VoiceConvertHandle shareInstance] playWithData:data];
    [self encodeData:data];
}

- (void)server:(BNRServer *)server peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    
}

- (void)client:(BNRClient *)client foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    //发现附近的用户
    [(BNRClient *)self.manager connectAvailableServer:peerID];
}

//如何客户端监测到断开了，再去重新连接
- (void)client:(BNRClient *)client connectServerStateChange:(MCSessionState)state
{
    if (self.roleType == RoleTypeClient) {
        if (state == MCSessionStateNotConnected) {
            [(BNRClient *)self.manager reConnect];
        }
    }
}

#pragma mark - voice delegate
- (void)covertedData:(NSData *)data
{
    //发送数据
    [self.manager sendData:data];
}

- (void)encodeData:(NSData *)data
{
    [h264Decoder decodeNalu:(uint8_t *)[data bytes] withSize:(uint32_t)data.length];
}

#pragma mark -  H264解码回调  H264HwDecoderImplDelegate delegare
- (void)displayDecodedFrame:(CVImageBufferRef )imageBuffer
{
    if(imageBuffer)
    {
        CVPixelBufferRef _pixelBuffer = CVPixelBufferRetain(imageBuffer);
        playLayer.pixelBuffer = imageBuffer;
        
        int frameWidth = (int)CVPixelBufferGetWidth(_pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(_pixelBuffer);
        
        CGRect frame = playLayer.frame;
        frame.size.width = frameWidth;
        frame.size.height = frameHeight;
        frame.origin.x = (Screen_Width-frameWidth)/2;
        
        playLayer.frame = frame;
        
        CVPixelBufferRelease(imageBuffer);
        CVPixelBufferRelease(_pixelBuffer);
    }
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}

@end
