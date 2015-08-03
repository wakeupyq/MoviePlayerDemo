//
//  ViewController.m
//  MovieplayerDemo
//
//  Created by yangqin on 15/6/4.
//  Copyright (c) 2015年 yangqin. All rights reserved.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"

#ifdef DEBUG

#define NSLOG(message) NSLog(@"%@",(message));

#endif

@interface ViewController () < ASIProgressDelegate, ASIHTTPRequestDelegate>

@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic, strong) UIButton *playbutton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UIProgressView *cacheProgress;
@property (nonatomic, strong) UILabel *timeLable;

@property (nonatomic, strong) UIButton *downloadeBtn;
@property (nonatomic, strong) UIProgressView *downloadeProgress;
@property (nonatomic, strong) UILabel *sizeLable;

@property (nonatomic, assign) BOOL isplaying;
@property (nonatomic, assign) BOOL isSliding;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, assign) double totalLength;
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, strong) ASINetworkQueue *downloadeQueue;
@property (nonatomic, strong) ASIHTTPRequest *request;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

/*   1. AVPlayer是比较底层的avFoundation的API
     2. MPMoviePlayerController 就是一个封装了AVPlayer的简单类，提供基本的UI界面，对付一般的播放要求
     3. MPMoviePlayerController 不能像AVPlayer那样同时播放多个文件，因为其底下是对AVPlayer的单例封装
 */
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"1" ofType:@"mp4"];
    NSURL *sourceMovieURL = [NSURL fileURLWithPath:filePath];
    
     NSURL *url = [NSURL URLWithString:@"http://61.154.14.22:1259/xasp/video/20140110/20140110184826.mp4"];
/*
//    使用MediaPlayer來播放影片
    MPMoviePlayerController *moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:sourceMovieURL];
    moviePlayer.view.frame = self.view.bounds;
    moviePlayer.controlStyle = MPMovieControlStyleNone;
    moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    
    // Play the movie!
    [self.view addSubview:moviePlayer.view];
    [moviePlayer play];
    
    // 使用AVPlayer來播放影片
    
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:sourceMovieURL options:nil];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.frame = self.view.layer.bounds;
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.view.layer addSublayer:playerLayer];
    [player play];
 */
    NSLog(@"scale = %f",[UIScreen mainScreen].scale);
    [self creatMoviePlayerWithURL:url];
    [self creatBottomView];
    [self creatTopView];
    self.totalLength = 0.0;
}

- (void)creatMoviePlayerWithURL:(NSURL *)sourceMovieURL
{
    //    使用MediaPlayer來播放影片
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:sourceMovieURL];
    self.moviePlayer.view.frame = self.view.bounds;
    self.moviePlayer.controlStyle = MPMovieControlStyleNone;
    self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    self.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerPlaybackStateDidChange) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.moviePlayer];

    [self.view addSubview:self.moviePlayer.view];
    
    self.isplaying = NO;

}

// 创建底部工具栏
- (void)creatBottomView
{
    CGRect bottomFrame = CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44);
    UIView *bottomView = [[UIView alloc] initWithFrame:bottomFrame];
    bottomView.backgroundColor = [UIColor whiteColor];
    
    // 播放暂停按钮
    CGRect playBtnFrame = CGRectMake(5, 0, 44, 44);
    self.playbutton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playbutton.frame = playBtnFrame;
    UIImage *playimage = [UIImage imageNamed:@"play"];
    [self.playbutton setImage:playimage forState:UIControlStateNormal];
    [self.playbutton addTarget:self action:@selector(playButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:self.playbutton];
    
    // 缓存进度条
    CGFloat cp_x = playBtnFrame.origin.x + playBtnFrame.size.width + 5;
    CGFloat cp_y = (CGRectGetHeight(bottomView.frame) - 2)/2;
    CGFloat cp_w = CGRectGetWidth(bottomView.frame) - cp_x - 5 - 80;
    CGRect cpFrame = CGRectMake(cp_x, cp_y, cp_w, 2);

    self.cacheProgress = [[UIProgressView alloc] initWithFrame:cpFrame];
    self.cacheProgress.backgroundColor = [UIColor greenColor];
    self.cacheProgress.progressViewStyle = UIProgressViewStyleDefault;
    [bottomView addSubview:self.cacheProgress];
    
    // 播放进度条
    CGRect psFrame = CGRectMake(cp_x, (CGRectGetHeight(bottomView.frame) - 31)/2, cp_w, 31);
    self.progressSlider = [[UISlider alloc] initWithFrame: psFrame];
    self.progressSlider.maximumValue = 1.0;
    [self.progressSlider setMaximumTrackTintColor:[UIColor clearColor]];
    [self.progressSlider setMinimumTrackTintColor:[UIColor clearColor]];
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"progressThumb"] forState:UIControlStateNormal];
    [self.progressSlider addTarget:self action:@selector(progressSliderVauleDidChange) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(progressSliderBeginVauleChange) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(progressSliderVauleEndChange) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpInside];
    [bottomView addSubview:self.progressSlider];
    
    // 时间
    CGRect timeLableFrame = CGRectMake(bottomView.frame.size.width - 80, 0, 80, 44);
    self.timeLable = [[UILabel alloc] initWithFrame:timeLableFrame];
    self.timeLable.textAlignment = NSTextAlignmentCenter;
    self.timeLable.backgroundColor = [UIColor greenColor];
    self.timeLable.adjustsFontSizeToFitWidth = YES;
    self.timeLable.text = @"00:00:00/00:00:00";
    [bottomView addSubview:self.timeLable];
    [self.view addSubview:bottomView];
    
}

// 创建顶部工具栏

- (void)creatTopView
{
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    [topView setBackgroundColor:[UIColor whiteColor]];
    
    self.downloadeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.downloadeBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    self.downloadeBtn .frame = CGRectMake(5, 0, 44, 44);
    [self.downloadeBtn  setTitle:@"下载" forState:UIControlStateNormal];
    [self.downloadeBtn  addTarget:self action:@selector(downloadeButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:self.downloadeBtn ];
    
    self.downloadeProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(55, 21, 160, 2)];
    self.downloadeProgress.progressViewStyle = UIProgressViewStyleDefault;
    [topView addSubview:self.downloadeProgress];
    
    self.sizeLable = [[UILabel alloc] initWithFrame:CGRectMake(220, 0, 100, 44)];
    self.sizeLable.font = [UIFont systemFontOfSize:11];
    [topView addSubview:self.sizeLable];
    
    [self.view addSubview:topView];
}

#pragma mark - actions
- (void)playButtonAction:(id)sender
{
    if ( !self.isplaying) {
        [self.moviePlayer play];
//        self.isplaying = YES;
//        [self.playbutton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        
    } else {
        [self.moviePlayer pause];
//        self.isplaying = NO;
//        [self.playbutton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    }
    
}

- (void)downloadeButtonAction
{
    self.isDownloading = !self.isDownloading;
    
    // 创建网络请求队列
    if (!self.downloadeQueue) {
        self.downloadeQueue = [[ASINetworkQueue alloc] init];
        [self.downloadeQueue reset];
        [self.downloadeQueue setShowAccurateProgress:YES];
        [self.downloadeQueue go];
    }
   
    
    // 创建存放路径
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *tempPath = [path stringByAppendingPathComponent:@"temp"];
    NSString *savePath = [path stringByAppendingPathComponent:@"datas"];
    
    NSFileManager *fm =[NSFileManager defaultManager];
    NSError *error = nil;
    if (![fm fileExistsAtPath:tempPath]) {
        [fm createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (![fm fileExistsAtPath:savePath]) {
        [fm createDirectoryAtPath:savePath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
//    if (!self.request) {
    
        NSURL *url = [NSURL URLWithString:@"http://61.154.14.22:1259/xasp/video/20140110/20140110184826.mp4"];
       ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        request.delegate = self;
        [request setDownloadDestinationPath:[savePath stringByAppendingPathComponent:@"movie.mp4"]];
        [request setTemporaryFileDownloadPath:[tempPath  stringByAppendingPathComponent:@"movie.mp4"]];
        request.userInfo = [NSDictionary dictionaryWithObject:@"yangqin" forKey:@"name"];
        [request setDownloadProgressDelegate:self];
        [request setAllowResumeForFileDownloads:YES];
//   }
    
    if (!self.isDownloading) {
        [self.downloadeBtn setTitle:@"下载" forState:UIControlStateNormal];
        if ([[self.downloadeQueue operations] count] > 0) {
            NSLog(@"requests = %@",[self.downloadeQueue operations]);
             [[[self.downloadeQueue operations] objectAtIndex:0] clearDelegatesAndCancel];
        }
    } else {
        [self.downloadeBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [self.downloadeQueue addOperation:request];
    }
    

}

- (void)changeTheProgressState
{
    if (self.isSliding) {
        return;
    }
    self.progressSlider.value = self.moviePlayer.currentPlaybackTime / self.moviePlayer.duration ;
    self.cacheProgress.progress = self.moviePlayer.playableDuration / self.moviePlayer.duration;
    NSDateFormatter *currdateFormatter = [[NSDateFormatter alloc] init];
    NSDateFormatter *totaldateFormatter = [[NSDateFormatter alloc] init];
    
    if (self.moviePlayer.currentPlaybackTime / 3600 < 1) {
        currdateFormatter.dateFormat = @"mm:ss";
    } else {
        currdateFormatter.dateFormat = @"hh:mm:ss";
    }
    
    if (self.moviePlayer.duration / 3600 < 1) {
        totaldateFormatter.dateFormat = @"mm:ss";
    } else {
        totaldateFormatter.dateFormat = @"hh:mm:ss";
    }
    
//    NSDate *originalDate = [dateFormatter dateFromString:@"00:00:00"];
    NSDate *currdate = [NSDate dateWithTimeIntervalSince1970:self.moviePlayer.currentPlaybackTime];
    NSDate *totalDate = [NSDate dateWithTimeIntervalSince1970:self.moviePlayer.duration];
    
    NSString *currDateStr = [currdateFormatter stringFromDate:currdate];
    NSString *totalDateStr = [totaldateFormatter stringFromDate:totalDate];
    
    NSString *timeStr = [NSString stringWithFormat:@"%@/%@", currDateStr, totalDateStr];
    self.timeLable.text = timeStr;
    NSLog(@"currenttime = %f,cachtime = %f, totaltime = %f",self.moviePlayer.currentPlaybackTime,self.moviePlayer.playableDuration, self.moviePlayer.duration);

}

- (void)progressSliderBeginVauleChange
{
    [self.moviePlayer pause];
    self.isSliding = YES;
}

- (void)progressSliderVauleEndChange
{
    [self.moviePlayer play];
    self.isSliding = NO;
}

- (void)progressSliderVauleDidChange
{
    CGFloat currentTime = self.moviePlayer.duration * self.progressSlider.value;
    self.moviePlayer.currentPlaybackTime = currentTime;
}


#pragma mark - Notification

- (void)moviePlayerPlaybackStateDidChange
{
    if ( self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        self.isplaying = YES;
        [self.playbutton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        if (self.timer == nil || !self.timer.valid) {
            self.timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(changeTheProgressState) userInfo:nil repeats:YES];
        }
        
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
        
    } else {
        self.isplaying = NO;
        [self.playbutton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        [self.timer invalidate];
    }
}

#pragma mark - ASIHTTPRequestDelegate

-(void)request:(ASIHTTPRequest *)request didReceiveResponseHeaders:(NSDictionary *)responseHeaders
{
//   NSString *sizeStr = [[NSUserDefaults standardUserDefaults] objectForKey:[request.userInfo objectForKey:@"name"]];
//    if (sizeStr == nil) {
//        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld", request.contentLength] forKey:[request.userInfo objectForKey:@"name"]];
//    }
    if (self.totalLength == 0.0) {
        self.totalLength = (double)request.contentLength / 1024.0 / 1024.0;
    }
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes
{
//    double totalLength = [[[NSUserDefaults standardUserDefaults] objectForKey:[request.userInfo objectForKey:@"name"]] doubleValue] / 1024.0 / 1024.0;
//      self.receiveLength += bytes / 1024.0 / 1024.0;
////    self.downloadeProgress.progress = self.receiveLength / totalLength;
//    self.sizeLable.text = [NSString stringWithFormat:@"%.2fMB/%.2fMB", self.receiveLength, totalLength];
}

- (void)setProgress:(float)newProgress{
    self.downloadeProgress.progress = newProgress;
    
//    double totalLength = [[[NSUserDefaults standardUserDefaults] objectForKey:[request.userInfo objectForKey:@"name"]] doubleValue] / 1024.0 / 1024.0;
//    self.receiveLength = self.;
    //    self.downloadeProgress.progress = self.receiveLength / totalLength;
    self.sizeLable.text = [NSString stringWithFormat:@"%.2fMB/%.2fMB", self.totalLength * newProgress, self.totalLength];
}
- (void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"requestFinished, queue count = %d",self.downloadeQueue.requestsCount);
    
}

-(void)requestFailed:(ASIHTTPRequest *)request
{
    NSLog(@"requestFailed");
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
