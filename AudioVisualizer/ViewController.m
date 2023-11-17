//
//  ViewController.m
//  AudioVisualizer
//
//  Created by Diana on 6/28/16.
//  Copyright © 2016 Diana. All rights reserved.
//

#import "ViewController.h"

#define visualizerAnimationDuration 0.01

@implementation ViewController
{
    double lowPassReslts;
    double lowPassReslts1;
    NSTimer *visualizerTimer;
    NSMutableArray *_songArr;
}

- (void)viewDidLoad
{
    _songArr = [[NSMutableArray alloc]init];
    [super viewDidLoad];
    [self initObservers];
    [self initAudioPlayer];
    [self initAudioVisualizer];
    //[self requestAuthorizationForMediaLibrary];
    [self getItunesMusic];
    //[self findArtistList];
}

- (void) didEnterBackground
{
    [self stopAudioVisualizer];
}

- (void) didEnterForeground
{
    if (_playPauseButton.isSelected)
    {
        [self startAudioVisualizer];
    }
}

#pragma mark - Initializations
- (void) initObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void) initAudioPlayer
{
    NSError *error;
    
    //设置锁屏仍能继续播放
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    
    //参考：https://www.cnblogs.com/A--G/p/4624526.html
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL success = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    if(!success)
    {
        NSLog(@"error doing outputaudioportoverride - %@", [error localizedDescription]);
    }
//    UInt32 audioRoute = kAudioSessionOverrideAudioRoute_Speaker;
//    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute,sizeof(audioRoute), &audioRoute);

    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample" ofType:@"mp3"]];
    
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    [_audioPlayer setMeteringEnabled:YES];

    if (error)
    {
        NSLog(@"Error in audioPlayer: %@", [error localizedDescription]);
    }
    else
    {
        _audioPlayer.delegate = self;
        [_audioPlayer prepareToPlay];
    }
}

- (void) initAudioVisualizer
{
    CGRect frame = _visualizerView.frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    UIColor *visualizerColor = [UIColor colorWithRed:255.0 / 255.0 green:84.0 / 255.0 blue:116.0 / 255.0 alpha:1.0];
    _audioVisualizer = [[AudioVisualizer alloc] initWithBarsNumber:50 frame:frame andColor:visualizerColor];
    [_visualizerView addSubview:_audioVisualizer];
}

#pragma mark -
- (IBAction)playPauseButtonPressed:(id)sender
{
    if (_playPauseButton.isSelected)
    {
        [_audioPlayer pause];
        [_playPauseButton setImage:[UIImage imageNamed:@"play_"] forState:UIControlStateNormal];
        [_playPauseButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateHighlighted];
        [_playPauseButton setSelected:NO];
        
        [self stopAudioVisualizer];
    }
    else
    {
        [_audioPlayer play];
        [_playPauseButton setImage:[UIImage imageNamed:@"pause_"] forState:UIControlStateNormal];
        [_playPauseButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateHighlighted];
        [_playPauseButton setSelected:YES];
        
        [self startAudioVisualizer];
    }
}

- (void) updateLabels
{
    _currentTimeLabel.text = [self convertSeconds:_audioPlayer.currentTime];
    _remainingTimeLabel.text = [self convertSeconds:_audioPlayer.duration - _audioPlayer.currentTime];
}

- (NSString *)convertSeconds:(float)secs
{
    if (secs != secs || secs < 0.1)
    {
        secs = 0;
    }
    int totalSeconds = (int)secs;
    if (secs - totalSeconds > 0.45)
        totalSeconds++;
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    if(hours > 0)
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}

#pragma mark - Visualizer Methods
- (void) visualizerTimer:(CADisplayLink *)timer
{
    [_audioPlayer updateMeters];
    
    const double ALPHA = 1.05;
    
    double averagePowerForChannel = pow(10, (0.05 * [_audioPlayer averagePowerForChannel:0]));
    lowPassReslts = ALPHA * averagePowerForChannel + (1.0 - ALPHA) * lowPassReslts;
    
    double averagePowerForChannel1 = pow(10, (0.05 * [_audioPlayer averagePowerForChannel:1]));
    lowPassReslts1 = ALPHA * averagePowerForChannel1 + (1.0 - ALPHA) * lowPassReslts1;
    
    [_audioVisualizer animateAudioVisualizerWithChannel0Level:lowPassReslts andChannel1Level:lowPassReslts1];
    [self updateLabels];
}

- (void) stopAudioVisualizer
{
    [visualizerTimer invalidate];
    visualizerTimer = nil;
    [_audioVisualizer stopAudioVisualizer];
}

- (void) startAudioVisualizer
{
    [visualizerTimer invalidate];
    visualizerTimer = nil;
    visualizerTimer = [NSTimer scheduledTimerWithTimeInterval:visualizerAnimationDuration target:self selector:@selector(visualizerTimer:) userInfo:nil repeats:YES];
}

#pragma mark - Audio Player Delegate Methods
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"audioPlayerDidFinishPlaying");
    
    [_playPauseButton setImage:[UIImage imageNamed:@"play_"] forState:UIControlStateNormal];
    [_playPauseButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateHighlighted];
    [_playPauseButton setSelected:NO];
    _currentTimeLabel.text = @"00:00";
    _remainingTimeLabel.text = [self convertSeconds:_audioPlayer.duration];
    [self stopAudioVisualizer];
}

-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"audioPlayerDecodeErrorDidOccur");
    
    [_playPauseButton setImage:[UIImage imageNamed:@"play_"] forState:UIControlStateNormal];
    [_playPauseButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateHighlighted];
    [_playPauseButton setSelected:NO];
    _currentTimeLabel.text = @"00:00";
    _remainingTimeLabel.text = @"00:00";
    
    [self stopAudioVisualizer];
}

-(void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
    NSLog(@"audioPlayerBeginInterruption");
}

-(void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
    NSLog(@"audioPlayerEndInterruption");
}

// MARK:- 判断是否有权限
- (void)requestAuthorizationForMediaLibrary {
    
    __weak typeof(self) weakSelf = self;
    
    // 请求媒体资料库权限
    MPMediaLibraryAuthorizationStatus authStatus = [MPMediaLibrary authorizationStatus];
    
    if (authStatus != MPMediaLibraryAuthorizationStatusAuthorized) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        if (appName == nil) {
            appName = @"APP";
        }
        NSString *message = [NSString stringWithFormat:@"允许%@访问你的媒体资料库？", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)resolverMediaItem:(MPMediaItem *)music {
    // 歌名
    NSString *name = [music valueForProperty:MPMediaItemPropertyTitle];
    // 歌曲路径
    NSURL *fileURL = [music valueForProperty:MPMediaItemPropertyAssetURL];
    // 歌手名字
    NSString *singer = [music valueForProperty:MPMediaItemPropertyArtist];
    if(singer == nil)
    {
        singer = @"未知歌手";
    }
    // 歌曲时长（单位：秒）
    NSTimeInterval duration = [[music valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    NSString *time = @"";
    if((int)duration % 60 < 10) {
        time = [NSString stringWithFormat:@"%d:0%d",(int)duration / 60,(int)duration % 60];
    }else {
        time = [NSString stringWithFormat:@"%d:%d",(int)duration / 60,(int)duration % 60];
    }
    // 歌曲插图（没有就返回 nil）
    MPMediaItemArtwork *artwork = [music valueForProperty:MPMediaItemPropertyArtwork];
    UIImage *image;
    if (artwork) {
        image = [artwork imageWithSize:CGSizeMake(72, 72)];
    }else {
        image = [UIImage imageNamed:@"duanshipin"];
    }
    
    [_songArr addObject:@{@"name": name,
                          @"fileURL": fileURL,
                          @"singer": singer,
                          @"time": time,
                          @"image": image,
                          }];
}

// MARK:- 获取 iTunes 中的音乐
- (void)getItunesMusic {
    [_songArr removeAllObjects];//删除全部元素
    // 创建媒体选择队列
    MPMediaQuery *query = [[MPMediaQuery alloc] init];
    // 创建读取条件
    MPMediaPropertyPredicate *albumNamePredicate = [MPMediaPropertyPredicate predicateWithValue:[NSNumber numberWithInt:MPMediaTypeMusic] forProperty:MPMediaItemPropertyMediaType];
    // 给队列添加读取条件
    [query addFilterPredicate:albumNamePredicate];
    // 从队列中获取条件的数组集合
    NSArray *itemsFromGenericQuery = [query items];
    NSLog(@"Logging items from a generic query...");
    // 遍历解析数据
    for (MPMediaItem *music in itemsFromGenericQuery) {
        [self resolverMediaItem:music];
        //MPMediaItem 转换成 NSUrl
        //NSURL* assetUrl = [music valueForProperty:MPMediaItemPropertyAssetURL];
        NSLog (@"%@, %@, %@", music.title, music.assetURL,music.artist);
    }
}

//扫描本地音乐文件，返回艺术家列表 需要库MediaPlayer.framework
-(NSArray*) findArtistList {
    NSMutableArray *artistList = [[NSMutableArray alloc]init];
    MPMediaQuery *listQuery = [MPMediaQuery playlistsQuery];//播放列表
    NSArray *playlist = [listQuery collections];//播放列表数组
    NSLog(@"findArtistList>Logging items from a generic query...%@", playlist);
    for (MPMediaPlaylist * list in playlist) {
        NSArray *songs = [list items];//歌曲数组
        for (MPMediaItem *music in songs) {
            NSString *title =[music valueForProperty:MPMediaItemPropertyTitle];//歌曲名
            //歌手名
            NSString *artist =[[music valueForProperty:MPMediaItemPropertyArtist] uppercaseString];
            if(artist!=nil&&![artistList containsObject:artist]){
                [artistList addObject:artist];
            }
            NSLog (@"%@, %@, %@", music.title, music.assetURL,music.artist);
        }
    }
    return artistList;
}

@end
