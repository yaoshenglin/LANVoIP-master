//
// MBProgressHUD.m
// Version 0.5
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"
#import "CTB.h"

#if __has_feature(objc_arc)
	#define MB_AUTORELEASE(exp) exp
	#define MB_RELEASE(exp) exp
	#define MB_RETAIN(exp) exp
#else
	#define MB_AUTORELEASE(exp) [exp autorelease]
	#define MB_RELEASE(exp) [exp release]
	#define MB_RETAIN(exp) [exp retain]
#endif

#define iPhone [[[UIDevice currentDevice] systemVersion] floatValue]

static const CGFloat kPadding = 4.f;
static const CGFloat kLabelFontSize = 16.f;
static const CGFloat kDetailsLabelFontSize = 12.f;


@interface MBProgressHUD ()

- (void)setupLabels;
- (void)registerForKVO;
- (void)unregisterFromKVO;
- (NSArray *)observableKeypaths;
- (void)registerForNotifications;
- (void)unregisterFromNotifications;
- (void)updateUIForKeypath:(NSString *)keyPath;
- (void)hideUsingAnimation:(BOOL)animated;
- (void)showUsingAnimation:(BOOL)animated;
- (void)done;
- (void)updateIndicators;
- (void)handleGraceTimer:(NSTimer *)theTimer;
- (void)handleMinShowTimer:(NSTimer *)theTimer;
- (void)setTransformForCurrentOrientation:(BOOL)animated;
- (void)cleanUp;
- (void)launchExecution;
- (void)deviceOrientationDidChange:(NSNotification *)notification;
- (void)hideDelayed:(NSNumber *)animated;

@property (MB_STRONG) UIView *indicator;
@property (MB_STRONG) NSTimer *graceTimer;
@property (MB_STRONG) NSTimer *minShowTimer;
@property (MB_STRONG) NSDate *showStarted;
@property (assign) CGSize size;

@end


@implementation MBProgressHUD 
{
	BOOL useAnimation;
	SEL methodForExecution;
	id targetForExecution;
	id objectForExecution;
	UILabel *label;
	UILabel *detailsLabel;
	BOOL isFinished;
	CGAffineTransform rotationTransform;
}

#pragma mark - Properties

@synthesize animationType;
@synthesize delegate;
@synthesize opacity;
@synthesize labelFont;
@synthesize detailsLabelFont;
@synthesize indicator;
@synthesize xOffset;
@synthesize yOffset;
@synthesize minSize;
@synthesize square;
@synthesize margin;
@synthesize dimBackground;
@synthesize graceTime;
@synthesize minShowTime;
@synthesize graceTimer;
@synthesize minShowTimer;
@synthesize taskInProgress;
@synthesize removeFromSuperViewOnHide;
@synthesize customView;
@synthesize showStarted;
@synthesize mode;
@synthesize labelText;
@synthesize detailsLabelText;
@synthesize progress;
@synthesize size;
//@synthesize Point_Y;

#pragma mark - Class methods

+ (MBProgressHUD *)showHUDAddedTo:(UIView *)view animated:(BOOL)animated
{
	MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:view];
	[view addSubview:hud];
	[hud show:animated];
	return MB_AUTORELEASE(hud);
}

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated
{
	MBProgressHUD *hud = [MBProgressHUD HUDForView:view];
	if (hud != nil) {
		hud.removeFromSuperViewOnHide = YES;
		[hud hide:animated];
		return YES;
	}
	return NO;
}

+ (NSUInteger)hideAllHUDsForView:(UIView *)view animated:(BOOL)animated
{
	NSArray *huds = [self allHUDsForView:view];
	for (MBProgressHUD *hud in huds) {
		hud.removeFromSuperViewOnHide = YES;
		[hud hide:animated];
	}
	return [huds count];
}

+ (MBProgressHUD *)HUDForView:(UIView *)view
{
	MBProgressHUD *hud = nil;
	NSArray *subviews = view.subviews;
	Class hudClass = [MBProgressHUD class];
	for (UIView *view in subviews) {
		if ([view isKindOfClass:hudClass]) {
			hud = (MBProgressHUD *)view;
		}
	}
	return hud;
}

+ (NSArray *)allHUDsForView:(UIView *)view
{
	NSMutableArray *huds = [NSMutableArray array];
	NSArray *subviews = view.subviews;
	Class hudClass = [MBProgressHUD class];
	for (UIView *view in subviews) {
		if ([view isKindOfClass:hudClass]) {
			[huds addObject:view];
		}
	}
	return [NSArray arrayWithArray:huds];
}

+ (MBProgressHUD *)showRuningView:(UIView *)View
{
    MBProgressHUD *hudView = [[self class] showRuningView:View activity:UIActivityIndicatorViewStyleWhiteLarge];
    hudView.yOffset = 0;
    //hudView.msgBackground = [UIColor clearColor];
    //hudView.mode = MBProgressHUDModeActivity;
    return hudView;
}

+ (MBProgressHUD *)showRuningView:(UIView *)View activity:(UIActivityIndicatorViewStyle)style
{
    MBProgressHUD *hudView = nil;
    NSArray *subviews = View.subviews;
    for (UIView *view in subviews) {
		if ([view isKindOfClass:[self class]] && view.tag == 500) {
			hudView = (MBProgressHUD *)view;
		}
	}
    
    if (hudView) {
        [hudView removeFromSuperview];
    }
    
    hudView = [[MBProgressHUD alloc] initWithView:View activity:style];
    hudView.tag = 500;
    hudView.yOffset = -32;
    //[View addSubview:hudView];
    [View insertSubview:hudView atIndex:5];
    [View bringSubviewToFront:hudView];
    [hudView show:YES];
    return hudView;
}

+ (UIImageView *)initWithImgName:(NSString *)imgName
{
    UIImageView *imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imgName]];
    return imgView;
}

#pragma mark - --------Lifecycle--------------------------------
- (id)initWithFrame:(CGRect)frame 
{
	self = [super initWithFrame:frame];
	if (self) {
		// Set default values for properties
		self.animationType = MBProgressHUDAnimationFade;
		self.mode = MBProgressHUDModeIndeterminate;
		self.labelText = nil;
		self.detailsLabelText = nil;
		self.opacity = 0.5f;//不透明度
		self.labelFont = [UIFont boldSystemFontOfSize:kLabelFontSize];
		self.detailsLabelFont = [UIFont boldSystemFontOfSize:kDetailsLabelFontSize];
		self.xOffset = 0.0f;
		self.yOffset = 0.0f;
		self.dimBackground = NO;//暗淡的背景
		self.margin = 20.0f;
		self.graceTime = 0.0f;
		self.minShowTime = 0.0f;
		self.removeFromSuperViewOnHide = NO;//隐藏时从父级视图上移除
		self.minSize = CGSizeZero;
		self.square = NO;
		self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin 
								| UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

		// Transparent background
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		// Make it invisible for now
		self.alpha = 0.0f;
		
		taskInProgress = NO;
		rotationTransform = CGAffineTransformIdentity;
		
		[self setupLabels];//添加label
		[self updateIndicators];//确定指示器类型
		[self registerForKVO];// KVO
		[self registerForNotifications];//监测屏幕方向变化
	}
	return self;
}

#pragma mark - --------初始化活动指示器----------------
- (id)initWithView:(UIView *)view
{
	NSAssert(view, @"View must not be nil.");
	id me = [self initWithFrame:view.frame];
	// We need to take care of rotation ourselfs if we're adding the HUD to a window
	if ([view isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:NO];
	}
    
    //CGFloat ScreenHigh = [UIScreen mainScreen].bounds.size.height;
    //Point_Y = ScreenHigh<568 ? ScreenHigh*0.4 : ScreenHigh/3;
    //Point_Y = Point_Y - 30;
	return me;
}

- (id)initWithView:(UIView *)view activity:(UIActivityIndicatorViewStyle)style
{
    self.activityStyle = style;
	NSAssert(view, @"View must not be nil.");
	id me = [self initWithFrame:view.bounds];
	// We need to take care of rotation ourselfs if we're adding the HUD to a window
	if ([view isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:NO];
	}
	return me;
}

- (id)initWithWindow:(UIWindow *)window
{
	return [self initWithView:window];
}

- (void)dealloc
{
	[self unregisterFromNotifications];
	[self unregisterFromKVO];
#if !__has_feature(objc_arc)
	[indicator release];
	[label release];
	[detailsLabel release];
	[labelText release];
	[detailsLabelText release];
	[graceTimer release];
	[minShowTimer release];
	[showStarted release];
	[customView release];
	[super dealloc];
#endif
}

#pragma mark - Show & hide

- (void)show:(BOOL)animated 
{
	useAnimation = animated;
    [self.superview bringSubviewToFront:self];
	// If the grace time is set postpone the HUD display
	if (self.graceTime > 0.0) {
		self.graceTimer = [NSTimer scheduledTimerWithTimeInterval:self.graceTime target:self selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
	} 
	// ... otherwise show the HUD imediately 
	else {
		[self setNeedsDisplay];
		[self showUsingAnimation:useAnimation];
	}
}

- (UIView *)viewWithCustom
{
    int count = 12;
    CGFloat delay = count * 0.125;
    UIImage *image = [UIImage imageNamed:@"加载拼接图"];
    CGFloat w = image.size.width/count;
    CGFloat h = image.size.height;
    CGFloat ScreenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat ScreenH = [UIScreen mainScreen].bounds.size.height;
    UIView *vActivity = [[UIView alloc] initWithFrame:CGRectMake(ScreenW/2-80, ScreenH/2-64-45, 160, 90)];
    vActivity.layer.cornerRadius = 7;
    
    //登陆上方图片
    UIImageView *imgLoading = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, w, h)];//(110, 22)
    imgLoading.center = CGPointMake(vActivity.frame.size.width/2, vActivity.frame.size.height/2-15);
    NSArray *listImg = [CTB getImagesWith:image count:count];
    imgLoading.animationImages = listImg;
    imgLoading.animationDuration = delay;
    [imgLoading startAnimating];
    [vActivity addSubview:imgLoading];
    
    return vActivity;
}

- (void)showCustomView:(BOOL)animated
{
    [self show:animated];
    self.mode = MBProgressHUDModeCustomView;
    
    self.customView = [self viewWithCustom];
    
    self.msgBackground = [UIColor clearColor];
}

- (void)showCustomView:(BOOL)animated text:(NSString *)text backColor:(UIColor *)backColor
{
    [self show:animated];
    self.mode = MBProgressHUDModeCustomView;
    UIView *vActivity = [self viewWithCustom];
    
    UILabel *lblLoading = [[UILabel alloc] initWithFrame:CGRectMake(10, 55, vActivity.frame.size.width-20, 20)];
    lblLoading.textColor = [UIColor whiteColor];
    lblLoading.textAlignment = NSTextAlignmentCenter;
    lblLoading.font = [UIFont systemFontOfSize:16];
    lblLoading.text = text;
    [vActivity addSubview:lblLoading];
    
    self.customView = vActivity;
    self.msgBackground = [UIColor clearColor];
}

- (MBProgressHUD *)reShowIn:(UIView *)View
{
    UIView *superView = self.superview;
    [self removeFromSuperview];
    
    if (!superView) {
        superView = View;
    }
    
    MBProgressHUD *hudView = [MBProgressHUD showRuningView:superView];
    return hudView;
}

- (void)hide:(BOOL)animated 
{
	useAnimation = animated;
	// If the minShow time is set, calculate how long the hud was shown,
	// and pospone the hiding operation if necessary
	if (self.minShowTime > 0.0 && showStarted) {
		NSTimeInterval interv = [[NSDate date] timeIntervalSinceDate:showStarted];
		if (interv < self.minShowTime) {
			self.minShowTimer = [NSTimer scheduledTimerWithTimeInterval:(self.minShowTime - interv) target:self 
								selector:@selector(handleMinShowTimer:) userInfo:nil repeats:NO];
			return;
		} 
	}
	// ... otherwise hide the HUD immediately
	[self hideUsingAnimation:useAnimation];
}

- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay 
{
	[self performSelector:@selector(hideDelayed:) withObject:@(animated) afterDelay:delay];
}

- (void)hideDelayed:(NSNumber *)animated 
{
	[self hide:[animated boolValue]];
}

+ (MBProgressHUD *)showMsg:(NSString *)msg delay:(NSTimeInterval)delay View:(UIView *)View
{
    MBProgressHUD *hudView = [MBProgressHUD HUDForView:View];
    if (hudView) {
        [hudView removeFromSuperview];
    }
    
    hudView = [MBProgressHUD showRuningView:View];
    [hudView showDetailMsg:msg delay:delay];
    hudView.removeFromSuperViewOnHide = YES;
    return hudView;
}

+ (MBProgressHUD *)showMsg:(NSString *)msg delay:(NSTimeInterval)delay View:(UIView *)View yOffset:(CGFloat)y
{
    MBProgressHUD *hudView = [self showMsg:msg delay:delay View:View];
    hudView.yOffset = y;
    return hudView;
}

- (void)showDetailMsg:(NSString *)msg delay:(NSTimeInterval)delay
{
    if (![msg isKindOfClass:[NSString class]]) {
        return;
    }
    
    self.alpha = 1.0f;
    self.labelText = nil;
    self.mode = MBProgressHUDModeText;
    self.detailsLabelText = msg;
    self.detailsLabelFont = [UIFont systemFontOfSize:17];
    self.msgBackground = [UIColor colorWithWhite:0.1 alpha:0.8];
    [self hide:YES afterDelay:delay];
    
    [self performSelector:@selector(redetailsLabelText) withObject:nil afterDelay:delay+0.3];
}

- (void)showDetailMsg:(NSString *)msg delay:(NSTimeInterval)delay yOffset:(CGFloat)y
{
    [self showDetailMsg:msg delay:delay];
    self.yOffset = y;
    self.userInteractionEnabled = NO;
}

- (void)showImgWith:(NSString *)imgName text:(NSString *)text delay:(NSTimeInterval)delay
{
    self.customView = [MBProgressHUD initWithImgName:imgName];
    self.mode = MBProgressHUDModeCustomView;// Set custom view mode
    self.labelText = text;
    [self show:YES];
    [self hide:YES afterDelay:delay];
}

- (void)redetailsLabelText
{
    self.detailsLabelText = nil;
}

#pragma mark - Timer callbacks

- (void)handleGraceTimer:(NSTimer *)theTimer
{
	// Show the HUD only if the task is still running
	if (taskInProgress) {
		[self setNeedsDisplay];
		[self showUsingAnimation:useAnimation];
	}
}

- (void)handleMinShowTimer:(NSTimer *)theTimer 
{
	[self hideUsingAnimation:useAnimation];
}

#pragma mark - Internal show & hide operations

- (void)showUsingAnimation:(BOOL)animated 
{
	self.alpha = 0.0f;
	if (animated && animationType == MBProgressHUDAnimationZoom) {
		self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5f, 1.5f));
	}
	self.showStarted = [NSDate date];
	// Fade in
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.30];
		self.alpha = 1.0f;
		if (animationType == MBProgressHUDAnimationZoom) {
			self.transform = rotationTransform;
		}
		[UIView commitAnimations];
	}
	else {
		self.alpha = 1.0f;
	}
}

- (void)hideUsingAnimation:(BOOL)animated 
{
	// Fade out
	if (animated && showStarted) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.30];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationFinished:finished:context:)];
		// 0.02 prevents the hud from passing through touches during the animation the hud will get completely hidden
		// in the done method
		if (animationType == MBProgressHUDAnimationZoom) {
			self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5f, 0.5f));
		}
		self.alpha = 0.02f;
		[UIView commitAnimations];
	}
	else {
		self.alpha = 0.0f;
		[self done];
	}
	self.showStarted = nil;
}

- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void*)context 
{
	[self done];
}

- (void)done 
{
	isFinished = YES;
	self.alpha = 0.0f;
	if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
		[delegate performSelector:@selector(hudWasHidden:) withObject:self];
	}
    
    [self.customView removeFromSuperview];
    self.customView = nil;
    
	if (removeFromSuperViewOnHide) {
		[self removeFromSuperview];
	}
}

#pragma mark - Threading

- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated 
{
	methodForExecution = method;
	targetForExecution = MB_RETAIN(target);
	objectForExecution = MB_RETAIN(object);	
	// Launch execution in new thread
	self.taskInProgress = YES;
	[NSThread detachNewThreadSelector:@selector(launchExecution) toTarget:self withObject:nil];
	// Show HUD view
	[self show:animated];
}

- (void)launchExecution 
{
	@autoreleasepool {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		// Start executing the requested task
		[targetForExecution performSelector:methodForExecution withObject:objectForExecution];
#pragma clang diagnostic pop
		// Task completed, update view in main thread (note: view operations should
		// be done only in the main thread)
		[self performSelectorOnMainThread:@selector(cleanUp) withObject:nil waitUntilDone:NO];
	}
}

- (void)cleanUp 
{
	taskInProgress = NO;
	self.indicator = nil;
#if !__has_feature(objc_arc)
	[targetForExecution release];
	[objectForExecution release];
#endif
	[self hide:useAnimation];
}

#pragma mark - UI

- (void)setupLabels 
{
	label = [[UILabel alloc] initWithFrame:self.bounds];
	label.adjustsFontSizeToFitWidth = NO;
	label.textAlignment = NSTextAlignmentCenter;
	label.opaque = NO;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.font = self.labelFont;
	label.text = self.labelText;
	[self addSubview:label];
	
	detailsLabel = [[UILabel alloc] initWithFrame:self.bounds];
	detailsLabel.font = self.detailsLabelFont;
	detailsLabel.adjustsFontSizeToFitWidth = NO;
	detailsLabel.textAlignment = NSTextAlignmentCenter;
	detailsLabel.opaque = NO;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textColor = [UIColor whiteColor];
	detailsLabel.numberOfLines = 0;
	detailsLabel.font = self.detailsLabelFont;
	detailsLabel.text = self.detailsLabelText;
	[self addSubview:detailsLabel];
}

#pragma mark - --------更新----------------
- (void)updateIndicators
{
	BOOL isActivityIndicator = [indicator isKindOfClass:[UIActivityIndicatorView class]];
	BOOL isRoundIndicator = [indicator isKindOfClass:[MBRoundProgressView class]];
    
    if (!self.activityStyle) {
        self.activityStyle = UIActivityIndicatorViewStyleWhiteLarge;
    }
	
	if (mode == MBProgressHUDModeIndeterminate &&  !isActivityIndicator) {
		// Update to indeterminate indicator
		[indicator removeFromSuperview];
		self.indicator = MB_AUTORELEASE([[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:self.activityStyle]);
		[(UIActivityIndicatorView *)indicator startAnimating];
		[self addSubview:indicator];
	}
	else if (mode == MBProgressHUDModeDeterminate || mode == MBProgressHUDModeAnnularDeterminate) {
		if (!isRoundIndicator) {
			// Update to determinante indicator
			[indicator removeFromSuperview];
			self.indicator = MB_AUTORELEASE([[MBRoundProgressView alloc] init]);
			[self addSubview:indicator];
		}
		if (mode == MBProgressHUDModeAnnularDeterminate) {
			[(MBRoundProgressView *)indicator setAnnular:YES];
		}
	}
    else if (mode == MBProgressHUDModeActivity) {
        // Update to indeterminate indicator
        [indicator removeFromSuperview];
        self.indicator = MB_AUTORELEASE([[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:self.activityStyle]);
        [(UIActivityIndicatorView *)indicator startAnimating];
        [self addSubview:indicator];
        
        [label removeFromSuperview];
        [detailsLabel removeFromSuperview];
    }
	else if (mode == MBProgressHUDModeCustomView && customView != indicator) {
		// Update custom view indicator
		[indicator removeFromSuperview];
		self.indicator = customView;
		[self addSubview:indicator];
	} else if (mode == MBProgressHUDModeText) {
		[indicator removeFromSuperview];
		self.indicator = nil;
	}
}

- (void)setActivityStyle:(UIActivityIndicatorViewStyle)activityStyle
{
    _activityStyle = activityStyle;
    
    if ([self.indicator isKindOfClass:[UIActivityIndicatorView class]]) {
        UIActivityIndicatorView *activityView = (UIActivityIndicatorView *)self.indicator;
        activityView.activityIndicatorViewStyle = activityStyle;
    }
}

#pragma mark - Layout

- (void)layoutSubviews 
{
	
	CGRect bounds = self.bounds;
	
	// Determine the total widt and height needed
	CGFloat maxWidth = bounds.size.width - 4 * margin;
	CGSize totalSize = CGSizeZero;
	
	CGRect indicatorF = indicator.bounds;
	indicatorF.size.width = MIN(indicatorF.size.width, maxWidth);
	totalSize.width = MAX(totalSize.width, indicatorF.size.width);
	totalSize.height += indicatorF.size.height;
	
	CGSize labelSize = CGSizeZero;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        labelSize = [label.text sizeWithAttributes:@{NSFontAttributeName:label.font}];
    }else{
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
        labelSize = [label.text sizeWithFont:label.font];
#endif
    }
	labelSize.width = MIN(labelSize.width, maxWidth);
	totalSize.width = MAX(totalSize.width, labelSize.width);
	totalSize.height += labelSize.height;
	if (labelSize.height > 0.f && indicatorF.size.height > 0.f) {
		totalSize.height += kPadding;
	}

	CGFloat remainingHeight = bounds.size.height - totalSize.height - kPadding - 4 * margin; 
	CGSize maxSize = CGSizeMake(maxWidth, remainingHeight);
	CGSize detailsLabelSize = CGSizeZero;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        detailsLabelSize = [detailsLabel.text boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:detailsLabel.font} context:nil].size;
    }else{
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
        detailsLabelSize = [detailsLabel.text sizeWithFont:detailsLabel.font
                                         constrainedToSize:maxSize lineBreakMode:detailsLabel.lineBreakMode];
#endif
    }
	totalSize.width = MAX(totalSize.width, detailsLabelSize.width);
	totalSize.height += detailsLabelSize.height;
	if (detailsLabelSize.height > 0.f && (indicatorF.size.height > 0.f || labelSize.height > 0.f)) {
		totalSize.height += kPadding;
	}
	
	totalSize.width += 2 * margin;
	totalSize.height += 2 * margin;
	
	// Position elements
	CGFloat yPos = roundf(((bounds.size.height - totalSize.height) / 2)) + margin + yOffset;
	CGFloat xPos = xOffset;
	indicatorF.origin.y = yPos;
	indicatorF.origin.x = roundf((bounds.size.width - indicatorF.size.width) / 2) + xPos;
	indicator.frame = indicatorF;
	yPos += indicatorF.size.height;
	
	if (labelSize.height > 0.f && indicatorF.size.height > 0.f) {
		yPos += kPadding;
	}
	CGRect labelF;
	labelF.origin.y = yPos;
	labelF.origin.x = roundf((bounds.size.width - labelSize.width) / 2) + xPos;
	labelF.size = labelSize;
	label.frame = labelF;
	yPos += labelF.size.height;
	
	if (detailsLabelSize.height > 0.f && (indicatorF.size.height > 0.f || labelSize.height > 0.f)) {
		yPos += kPadding;
	}
	CGRect detailsLabelF;
	detailsLabelF.origin.y = yPos;
	detailsLabelF.origin.x = roundf((bounds.size.width - detailsLabelSize.width) / 2) + xPos;
	detailsLabelF.size = detailsLabelSize;
	detailsLabel.frame = detailsLabelF;
	
	// Enforce minsize and quare rules
	if (square) {
		CGFloat max = MAX(totalSize.width, totalSize.height);
		if (max <= bounds.size.width - 2 * margin) {
			totalSize.width = max;
		}
		if (max <= bounds.size.height - 2 * margin) {
			totalSize.height = max;
		}
	}
	if (totalSize.width < minSize.width) {
		totalSize.width = minSize.width;
	} 
	if (totalSize.height < minSize.height) {
		totalSize.height = minSize.height;
	}
	
	self.size = totalSize;
}

- (CGRect)setRect:(CGRect)rect withSize:(CGSize)newSize
{
    CGPoint center = CGPointMake(rect.origin.x+rect.size.width/2, rect.origin.y+rect.size.height/2);
    rect.size = newSize;
    rect.origin = CGPointMake(center.x-rect.size.width/2, center.y-rect.size.height/2);
    
    return rect;
}

#pragma mark - --------BG Drawing----------------
- (void)drawRect:(CGRect)rect 
{
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (dimBackground) {
		//Gradient colours
		size_t gradLocationsNum = 2;
		CGFloat gradLocations[2] = {0.0f, 1.0f};
		CGFloat gradColors[8] = {0.0f,0.0f,0.0f,0.0f,0.0f,0.0f,0.0f,0.75f};
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, gradColors, gradLocations, gradLocationsNum);
		CGColorSpaceRelease(colorSpace);
		//Gradient center
		CGPoint gradCenter = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
		//Gradient radius
		float gradRadius = MIN(self.bounds.size.width , self.bounds.size.height) ;
		//Gradient draw
		CGContextDrawRadialGradient (context, gradient, gradCenter,
									 0, gradCenter, gradRadius,
									 kCGGradientDrawsAfterEndLocation);
		CGGradientRelease(gradient);
	}
	
	// Center HUD
	CGRect allRect = self.bounds;
	// Draw rounded HUD bacgroud rect
	CGRect boxRect = CGRectMake(roundf((allRect.size.width - size.width) / 2) + self.xOffset,
								roundf((allRect.size.height - size.height) / 2) + self.yOffset, size.width, size.height);
	float radius = 10.0f;
	CGContextBeginPath(context);
	CGContextSetGrayFillColor(context, 0.0f, self.opacity);
    
    if (self.detailsLabelText.length > 0) {
        radius = 5.0f;
        CGSize newSize = CGSizeMake(boxRect.size.width-10, boxRect.size.height-30);
        boxRect = [self setRect:boxRect withSize:newSize];
    }
    
    //这里可以设置活动指示器的frame
    //boxRect = CGRectMake(boxRect.origin.x, Point_Y, boxRect.size.width, boxRect.size.height);
    //文字
    //label.frame = CGRectMake(label.frame.origin.x, Point_Y+70, label.frame.size.width, label.frame.size.height);
    //活动指示器
    //indicator.center = CGPointMake(indicator.center.x, Point_Y+40);
    
    if (self.msgBackground != NULL) {
        //显示框背景色
        CGContextSetFillColorWithColor(context, self.msgBackground.CGColor);
    }
    
    if (self.msgTextColor != NULL) {
        label.textColor = self.msgTextColor;//文字颜色
    }
    
	CGContextMoveToPoint(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect));
	CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMinY(boxRect) + radius, radius, 3 * (float)M_PI / 2, 0, 0);
	CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMaxY(boxRect) - radius, radius, 0, (float)M_PI / 2, 0);
	CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMaxY(boxRect) - radius, radius, (float)M_PI / 2, (float)M_PI, 0);
	CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect) + radius, radius, (float)M_PI, 3 * (float)M_PI / 2, 0);
	CGContextClosePath(context);
	CGContextFillPath(context);
}

#pragma mark - KVO

- (void)registerForKVO 
{
	for (NSString *keyPath in [self observableKeypaths]) {
		[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	}
}

- (void)unregisterFromKVO 
{
	for (NSString *keyPath in [self observableKeypaths]) {
		[self removeObserver:self forKeyPath:keyPath];
	}
}

- (NSArray *)observableKeypaths 
{
	return [NSArray arrayWithObjects:@"mode", @"customView", @"labelText", @"labelFont", 
			@"detailsLabelText", @"detailsLabelFont", @"progress", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context 
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(updateUIForKeypath:) withObject:keyPath waitUntilDone:NO];
	} else {
		[self updateUIForKeypath:keyPath];
	}
}

- (void)updateUIForKeypath:(NSString *)keyPath 
{
	if ([keyPath isEqualToString:@"mode"] || [keyPath isEqualToString:@"customView"]) {
		[self updateIndicators];
	} else if ([keyPath isEqualToString:@"labelText"]) {
		label.text = self.labelText;
	} else if ([keyPath isEqualToString:@"labelFont"]) {
		label.font = self.labelFont;
	} else if ([keyPath isEqualToString:@"detailsLabelText"]) {
		detailsLabel.text = self.detailsLabelText;
	} else if ([keyPath isEqualToString:@"detailsLabelFont"]) {
		detailsLabel.font = self.detailsLabelFont;
	} else if ([keyPath isEqualToString:@"progress"]) {
		if ([indicator respondsToSelector:@selector(setProgress:)]) {
			[(id)indicator setProgress:progress];
		}
		return;
	}
	[self setNeedsLayout];
	[self setNeedsDisplay];
}

#pragma mark - Notifications

- (void)registerForNotifications
{
 	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(deviceOrientationDidChange:) 
			   name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)unregisterFromNotifications 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
	UIView *superview = self.superview;
	if (!superview) {
		return;
	} else if ([superview isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:YES];
	} else {
		self.bounds = self.superview.bounds;
		[self setNeedsDisplay];
	}
}

- (void)setTransformForCurrentOrientation:(BOOL)animated
{
	// Stay in sync with the superview
	if (self.superview) {
		self.bounds = self.superview.bounds;
		[self setNeedsDisplay];
	}
	
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	float radians = 0;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		if (orientation == UIInterfaceOrientationLandscapeLeft) { radians = -M_PI_2; } 
		else { radians = M_PI_2; }
		// Window coordinates differ!
		self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
	} else {
		if (orientation == UIInterfaceOrientationPortraitUpsideDown) { radians = M_PI; } 
		else { radians = 0; }
	}
	rotationTransform = CGAffineTransformMakeRotation(radians);
	
	if (animated) {
		[UIView beginAnimations:nil context:nil];
	}
	[self setTransform:rotationTransform];
	if (animated) {
		[UIView commitAnimations];
	}
}

@end


@implementation MBRoundProgressView 
{
	float _progress;
	BOOL _annular;
}

#pragma mark - Accessors

- (float)progress 
{
	return _progress;
}

- (void)setProgress:(float)progress 
{
	_progress = progress;
	[self setNeedsDisplay];
}

- (BOOL)isAnnular 
{
	return _annular;
}

- (void)setAnnular:(BOOL)annular 
{
	_annular = annular;
	[self setNeedsDisplay];
}

#pragma mark - Lifecycle

- (id)init 
{
	return [self initWithFrame:CGRectMake(0.f, 0.f, 37.f, 37.f)];
}

- (id)initWithFrame:(CGRect)frame 
{
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		_progress = 0.f;
		_annular = NO;
	}
	return self;
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect 
{
	
	CGRect allRect = self.bounds;
	CGRect circleRect = CGRectInset(allRect, 2.0f, 2.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (_annular) {
		// Draw background
		CGFloat lineWidth = 5.f;
		UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
		processBackgroundPath.lineWidth = lineWidth;
		processBackgroundPath.lineCapStyle = kCGLineCapRound;
		CGPoint center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
		CGFloat radius = (self.bounds.size.width - lineWidth)/2;
		CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
		CGFloat endAngle = (2 * (float)M_PI) + startAngle;
		[processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[[UIColor colorWithRed:1 green:1 blue:1 alpha:0.1] set];
		[processBackgroundPath stroke];
		// Draw progress
		UIBezierPath *processPath = [UIBezierPath bezierPath];
		processPath.lineCapStyle = kCGLineCapRound;
		processPath.lineWidth = lineWidth;
		endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
		[processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[[UIColor whiteColor] set];
		[processPath stroke];
	} else {
		// Draw background
		CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 1.0f); // white
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.1f); // translucent white
		CGContextSetLineWidth(context, 2.0f);
		CGContextFillEllipseInRect(context, circleRect);
		CGContextStrokeEllipseInRect(context, circleRect);
		// Draw progress
		CGPoint center = CGPointMake(allRect.size.width / 2, allRect.size.height / 2);
		CGFloat radius = (allRect.size.width - 4) / 2;
		CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
		CGFloat endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f); // white
		CGContextMoveToPoint(context, center.x, center.y);
		CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
		CGContextClosePath(context);
		CGContextFillPath(context);
	}
}

@end

@implementation HUD

+ (MBProgressHUD *)showMsg:(NSString *)msg View:(UIView *)View
{
    MBProgressHUD *hud = [MBProgressHUD showMsg:msg delay:1.8f View:View];
    hud.userInteractionEnabled = NO;
    return hud;
}

+ (MBProgressHUD *)showBottomMsg:(NSString *)msg View:(UIView *)View
{
    MBProgressHUD *hud = [MBProgressHUD showMsg:msg delay:1.8f View:View yOffset:100.0];
    hud.userInteractionEnabled = NO;
    return hud;
}

+ (MBProgressHUD *)showMsg:(NSString *)msg delay:(NSTimeInterval)delay View:(UIView *)View
{
    MBProgressHUD *hud = [MBProgressHUD showMsg:msg delay:delay View:View];
    hud.userInteractionEnabled = NO;
    return hud;
}

+ (MBProgressHUD *)showBottomMsg:(NSString *)msg delay:(NSTimeInterval)delay View:(UIView *)View
{
    MBProgressHUD *hud = [MBProgressHUD showMsg:msg delay:delay View:View yOffset:100.0];
    hud.userInteractionEnabled = NO;
    return hud;
}

+ (MBProgressHUD *)showMsg:(NSString *)msg delay:(NSTimeInterval)delay View:(UIView *)View yOffset:(CGFloat)y
{
    MBProgressHUD *hud = [MBProgressHUD showMsg:msg delay:delay View:View yOffset:y];
    hud.userInteractionEnabled = NO;
    return hud;
}

@end
