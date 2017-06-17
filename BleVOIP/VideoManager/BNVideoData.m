//
//  BNVideoData.m
//  BleVOIP
//
//  Created by xy on 2017/6/16.
//  Copyright © 2017年 JustinYang. All rights reserved.
//

#import "BNVideoData.h"

@implementation BNVideoData

- (void)setupCamera
{
    NSError *error = nil;
    
    // Create the session
    _session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Create a device input with the device and add it to the session.
    _input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                   error:&error];
    if (!_input) {
        // Handling the error appropriately.
    }
    [_session addInput:_input];
    
    // Create a VideoDataOutput and add it to the session
    _output = [[AVCaptureVideoDataOutput alloc] init];
    [_session addOutput:_output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [_output setSampleBufferDelegate:self queue:queue];
    
    // Specify the pixel format
    _output.videoSettings =
    [NSDictionary dictionaryWithObject:@(kCVPixelFormatType_32BGRA)
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
    _output.minFrameDuration = CMTimeMake(1, 10);
    
    // Start the session running to start the flow of data
    
    // Assign session to an ivar.
    [self setSession:_session];
}

- (void)startRunning
{
    if (!_session.running) {
        [_session startRunning];
    }
}

- (void)stopRunning
{
    if (_session.running) {
        [_session stopRunning];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Create a UIImage from the sample buffer data
    __unused UIImage *img = [self imageFromSampleBuffer:sampleBuffer];
    
    /*
     dispatch_async(dispatch_get_main_queue(), ^{
     self.catchview.image=img;
     });
     */
    
    if ([_delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [_delegate captureOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    // Get the number of bytes per row for the pixel buffer
    u_int8_t *baseAddress = (u_int8_t *)malloc(bytesPerRow*height);
    memcpy( baseAddress, CVPixelBufferGetBaseAddress(imageBuffer), bytesPerRow * height     );
    
    // size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    
    //The context draws into a bitmap which is `width'
    //  pixels wide and `height' pixels high. The number of components for each
    //      pixel is specified by `space'
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    //CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationRight];
    free(baseAddress);
    // Release the Quartz image
    CGImageRelease(quartzImage);
    return (image);
}

@end
