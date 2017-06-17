//
//  BNVideoData.h
//  BleVOIP
//
//  Created by xy on 2017/6/16.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol BNVideoDataDelegate <NSObject>

- (void)covertedData:(NSData *)data;

@end

@interface BNVideoData : UIView<AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureOutput *videoDataOutput;
}

@property (nonatomic, weak) id delegate;
@property (nonatomic, retain) AVCaptureSession *session;
@property (nonatomic, retain) AVCaptureDeviceInput *input;
@property (nonatomic, retain) AVCaptureVideoDataOutput *output;
//@property (nonatomic, retain) AVCaptureVideoPreviewLayer *previewLayer;
//@property (nonatomic, retain) UIView *preview;

- (void)setupCamera;

- (void)startRunning;
- (void)stopRunning;

@end
