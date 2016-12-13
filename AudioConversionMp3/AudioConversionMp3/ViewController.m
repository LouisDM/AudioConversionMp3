//
//  ViewController.m
//  AudioConversionMp3
//
//  Created by 辜东明 on 2016/12/13.
//  Copyright © 2016年 辜东明. All rights reserved.
//

#import "ViewController.h"
#include "lame.h"
#import <AVFoundation/AVFoundation.h>
#import "NSString+FileSize.h"
//可以是wav 或者 caf wav比caf小2.5倍左右
#define kRecordAudioFile [NSString stringWithFormat:@"NWAudio_%ld.caf",(long)[[NSUserDefaults standardUserDefaults] integerForKey:@"NWAudio"]+1]
#define kRecordAudioFileMp3 [NSString stringWithFormat:@"NWAudio_%ld.mp3",(long)[[NSUserDefaults standardUserDefaults] integerForKey:@"NWAudio"]+1]
@interface ViewController ()<AVAudioRecorderDelegate>

@property (nonatomic,strong) AVAudioRecorder *audioRecorder;//音频录音机
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;//音频播放器，用于播放录音文件
@property (nonatomic,strong) NSTimer *timer;//录音声波监控（注意这里暂时不对播放进行监控）
@property (weak, nonatomic) IBOutlet UIProgressView *audioPower;//音频波动@end

@property (weak, nonatomic) IBOutlet UITextField *originalPath;

@property (weak, nonatomic) IBOutlet UITextField *afterPath;

@property (weak, nonatomic) IBOutlet UILabel *originalSize;

@property (weak, nonatomic) IBOutlet UILabel *afterSize;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setAudioSession];
    if(![[NSUserDefaults standardUserDefaults] integerForKey:@"NWAudio"])
    {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"NWAudio"];
    }
}

#pragma mark - 私有方法
/**
 *  设置音频会话
 */
-(void)setAudioSession{
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放和录音状态，以便可以在录制完之后播放录音
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive:YES error:nil];
}

/**
 *  取得录音文件保存路径
 *
 *  @return 录音文件路径
 */
-(NSURL *)getSavePath{
    NSString *urlStr=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    urlStr=[urlStr stringByAppendingPathComponent:kRecordAudioFile];
    NSLog(@"file path:%@",urlStr);
    NSURL *url=[NSURL fileURLWithPath:urlStr];
    return url;
}


/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
-(AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音文件保存路径
        NSURL *url=[self getSavePath];
        //创建录音格式设置
        NSDictionary *setting=[self getAudioSetting];
        //创建录音机
        NSError *error=nil;
        _audioRecorder=[[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}

/**
 *  创建播放器
 *
 *  @return 播放器
 */
-(AVAudioPlayer *)audioPlayer{
    if (!_audioPlayer) {
        NSURL *url=[self getSavePath];
        NSError *error=nil;
        _audioPlayer=[[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
        _audioPlayer.numberOfLoops=0;
        [_audioPlayer prepareToPlay];
        if (error) {
            NSLog(@"创建播放器过程中发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioPlayer;
}

/**
 *  录音声波监控定制器
 *
 *  @return 定时器
 */
-(NSTimer *)timer{
    if (!_timer) {
        _timer=[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
    }
    return _timer;
}

/**
 *  录音声波状态设置
 */
-(void)audioPowerChange{
    [self.audioRecorder updateMeters];//更新测量值
    float power= [self.audioRecorder averagePowerForChannel:0];//取得第一个通道的音频，注意音频强度范围时-160到0
    CGFloat progress=(1.0/160.0)*(power+160.0);
    NSLog(@"录音中。。。%.2f",progress);
    [self.audioPower setProgress:progress];
}
/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
-(NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM=[NSMutableDictionary dictionary];
    //设置录音格式
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dicM setObject:@(8000) forKey:AVSampleRateKey];
    //设置通道,这里采用单声道
    [dicM setObject:@(2) forKey:AVNumberOfChannelsKey];
    //每个采样点位数,分为8、16、24、32
    [dicM setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    //是否使用浮点数采样
    [dicM setObject:@(YES) forKey:AVLinearPCMIsFloatKey];
    //....其他设置等
    return dicM;
}
-(BOOL)tranftoMp3{
    //录音设置
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    //录音格式 无法使用
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    //采样率
    [recordSettings setValue :[NSNumber numberWithFloat:8000] forKey: AVSampleRateKey];//44100.0
    //通道数
    [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
    //线性采样位数
    [recordSettings setValue :[NSNumber numberWithInt:16] forKey: AVLinearPCMBitDepthKey];
    //音频质量,采样质量
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMax] forKey:AVEncoderAudioQualityKey];
    
    
    NSString *cafFilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:kRecordAudioFile];    //caf文件路径
    
    NSString *mp3FilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:kRecordAudioFileMp3];//存储mp3文件的路径
    
    
    @try {
        int read, write;
        FILE *pcm = fopen([cafFilePath cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
        
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header,跳过头文件 有的文件录制会有音爆，加上此句话去音爆
        FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_num_channels(lame, 2);//设置1为单通道，默认为2双通道
        lame_set_in_samplerate(lame, 8000.0);//11025.0
        //lame_set_VBR(lame, vbr_default);
        lame_set_brate(lame, 16);
        lame_set_mode(lame, 3);
        lame_set_quality(lame, 2);
        lame_init_params(lame);
        
        do {
            read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0) {
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            }else{
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            }
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
        
        
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        //删除原文件
        //[[NSFileManager defaultManager] removeItemAtPath:cafFilePath error:nil];
        
        NSLog(@"转换完毕");
    }
    
}

#pragma mark - UI事件
/**
 *  点击录音按钮
 *
 *  @param sender 录音按钮
 */
- (IBAction)recordClick:(UIButton *)sender {
    if (![self.audioRecorder isRecording]) {
        [self.audioRecorder record];//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
        self.timer.fireDate=[NSDate distantPast];
    }
    _originalPath.text = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
                    stringByAppendingPathComponent:kRecordAudioFile];
}

/**
 *  点击暂定按钮
 *
 *  @param sender 暂停/恢复按钮
 */
- (IBAction)pauseClick:(UIButton *)sender {
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder pause];
        self.timer.fireDate=[NSDate distantFuture];
    }else{
        [self.audioRecorder record];
        self.timer.fireDate=[NSDate distantPast];
    }
}

/**
 *  点击停止按钮
 *
 *  @param sender 停止按钮
 */
- (IBAction)stopClick:(UIButton *)sender {
    [self.audioRecorder stop];
    self.timer.fireDate=[NSDate distantFuture];
    self.audioPower.progress=0.0;
    _originalSize.text = [NSString stringWithFormat:@"原文件大小:%@",[_originalPath.text fileSize]];
    //开始转换成MP3
    [self tranftoMp3];
    _afterPath.text = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:kRecordAudioFileMp3];
    _afterSize.text = [NSString stringWithFormat:@"转换后大小:%@",[_afterPath.text fileSize]];
    [[NSUserDefaults standardUserDefaults] setInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"NWAudio"]+1 forKey:@"NWAudio"];
}

#pragma mark - 录音机代理方法
/**
 *  录音完成，录音完成后播放录音
 *
 *  @param recorder 录音机对象
 *  @param flag     是否成功
 */
-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    if (![self.audioPlayer isPlaying]) {
        NSLog(@"录音完成!开始播放");
        [self.audioPlayer play];
    }
    
}





@end
