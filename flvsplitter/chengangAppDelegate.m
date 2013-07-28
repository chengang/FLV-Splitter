//
//  chengangAppDelegate.m
//  flvsplitter
//
//  Created by 陈 钢 on 13-6-4.
//  Copyright (c) 2013年 陈 钢. All rights reserved.
//


#define FLV_SIZE_HEADER				9
#define FLV_SIZE_PREVIOUSTAGSIZE	4
#define FLV_SIZE_TAGHEADER			11

#define FLV_TAG_AUDIO		8
#define FLV_TAG_VIDEO		9
#define FLV_TAG_SCRIPTDATA	18

#define FLV_VIDEO_AVC	7
#define FLV_AUDIO_AAC	10

#define KEY_FRAME 1


#import "chengangAppDelegate.h"

@implementation chengangAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // code here to initialize application
    [valideFlvLabel setHidden:YES];
    [valideDirLabel setHidden:YES];
    [successLabel setHidden:YES];
    [failLabel setHidden:YES];
    [splitTime setObjectValue:@"60"];
}

- (IBAction) select_file:(id)sender
{
    NSString * fn;
    fn = [self file_selecter:@"file"];
    [filename setStringValue: fn ];
    Boolean isFlv = [self valideFLV: fn ];
    if( isFlv)
    {
        [valideFlvLabel setHidden:YES];
    }
    else
    {
        [valideFlvLabel setHidden:NO];
    }
}


- (IBAction) select_output:(id)sender
{
    NSString * dir;
    dir = [self file_selecter:@"dir"];
    [outputDir setStringValue: dir ];
    Boolean isWritable = [self valideDIR: dir];
    if (isWritable)
    {
        [valideDirLabel setHidden:YES];
    }
    else
    {
        [valideDirLabel setHidden:NO];
    }
}

- (IBAction) split_it:(id)sender
{
    NSInteger st = [[splitTime objectValue] integerValue] * 1000; // microsecond
    NSString * inputFilename = [filename objectValue];
    NSString * outputDirname = [outputDir objectValue];
    //NSLog(@"%ld,%@,%@,%@", st, inputFilename, outputDirname, outputFilename);
    
    if([self splitFlv:inputFilename outputDir:outputDirname splitTime:st])
    {
        [successLabel setHidden:NO];
        [failLabel setHidden:YES];
    }
    else
    {
        [successLabel setHidden:YES];
        [failLabel setHidden:NO];
    }
    
}

- (Boolean) splitFlv:(NSString *) inputFilename outputDir: (NSString *) outputDirname splitTime: (NSInteger) st
{
    NSString * inputFilename_basename = [[inputFilename lastPathComponent] stringByDeletingPathExtension];
    NSString * outputPrefix = [NSString stringWithFormat:@"%@/%@", outputDirname, inputFilename_basename];
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:inputFilename];
    NSFileManager *filemgr = [NSFileManager defaultManager];
    
    if (fh == nil)
    {
        return NO;
    }
    if (![self valideDIR:outputDirname] )
    {
        return NO;
    }
    
    NSData * flvHeader;
    flvHeader = [fh readDataOfLength: FLV_SIZE_HEADER + FLV_SIZE_PREVIOUSTAGSIZE];
    //NSLog(@"%@", flvHeader);
    
    NSInteger tagId = 0;
    NSInteger tagIdVideo = 0;
    NSInteger tagIdAudio = 0;
    NSInteger timeSplitted = 0;
    NSInteger fileSplitted = 0;
    NSData * flvAACFakeFrame = nil;
    NSData * flvAVCFakeFrame = nil;
    NSMutableData * flvDataBuf = [NSMutableData dataWithData:flvHeader];
    
    while(1)
    {
        NSDictionary * flvTag = [self readFlvTag: fh timeSplitted:timeSplitted splitTime:st ];
        
        if ([[flvTag objectForKey: @"tags"] integerValue] > 0)
        {
            tagId += [[flvTag objectForKey: @"tags"] integerValue];
            
            NSInteger tagType = [[flvTag objectForKey: @"tagType"] intValue];
            //NSInteger tagSize = [[flvTag objectForKey: @"tagSize"] intValue]; //unused
            NSInteger timeStamp = [[flvTag objectForKey: @"timeStamp"] intValue];
            NSData * tagData = [flvTag objectForKey: @"tagData"];
            NSInteger audioCodec = 0 ;
            NSInteger audioRate = 0 ;
            NSInteger audioSize = 0 ;
            NSInteger audioType = 0 ;
            NSInteger videoFrameType = 0 ;
            NSInteger videoCodec = 0 ;
            
            //NSLog(@"\n");
            //NSLog(@"tagId %ld", tagId);
            //NSLog(@"tagType %ld", tagType);
            //NSLog(@"tagSize %ld", tagSize);
            //NSLog(@"timeStamp %ld", timeStamp);
            //NSLog(@"tagDataLength %ld", [tagData length]);

            if ( tagType == 8 )
            {
                tagIdAudio++;
                audioCodec = [[flvTag objectForKey: @"audioCodec"] intValue];
                audioRate = [[flvTag objectForKey: @"audioRate"] intValue];
                audioSize = [[flvTag objectForKey: @"audioSize"] intValue];
                audioType = [[flvTag objectForKey: @"audioType"] intValue];
                
                //NSLog(@"audioCodec %ld", audioCodec);
                //NSLog(@"audioRate %ld", audioRate);
                //NSLog(@"audioSize %ld", audioSize);
                //NSLog(@"audioType %ld", audioType);
                if (tagIdAudio == 1 && audioCodec == 10)
                {
                    flvAACFakeFrame = [NSData dataWithData:tagData];
                    [flvDataBuf appendData:flvAACFakeFrame];
                }
            }
            else if ( tagType == 9 )
            {
                tagIdVideo++;
                videoFrameType = [[flvTag objectForKey: @"videoFrameType"] intValue];
                videoCodec = [[flvTag objectForKey: @"videoCodec"] intValue];
                
                //NSLog(@"videoFrameType %ld", videoFrameType);
                //NSLog(@"videoCodec %ld", videoCodec);
                if (tagIdVideo == 1 && videoCodec == 7)
                {
                    flvAVCFakeFrame = [NSData dataWithData:tagData];
                    [flvDataBuf appendData:flvAVCFakeFrame];
                }
            }
            
            if (timeStamp - timeSplitted >= st && videoFrameType == 1)
            {
                fileSplitted++;
                timeSplitted = timeStamp;
                
                NSString * outputfile = [NSString stringWithFormat:@"%@_%ld.flv", outputPrefix, fileSplitted];
                [filemgr createFileAtPath: outputfile contents: flvDataBuf attributes: nil];
                //NSLog(@"%@", outputfile);
                flvDataBuf = [NSMutableData dataWithData:flvHeader];
                if (flvAVCFakeFrame != nil) {
                    [flvDataBuf appendData:flvAVCFakeFrame];
                }
                if (flvAACFakeFrame != nil) {
                    [flvDataBuf appendData:flvAACFakeFrame];
                }
            }
            
            if ( tagType != 18 )
            {
                [flvDataBuf appendData:tagData];
            }
        }
        else
        {
            fileSplitted++;
            NSString * outputfile = [NSString stringWithFormat:@"%@_%ld.flv", outputPrefix, fileSplitted];
            [filemgr createFileAtPath: outputfile contents: flvDataBuf attributes: nil];
            break;
        }
        
    }
    [fh closeFile];
    
    return YES;
}


- (NSDictionary *) readFlvTag:(NSFileHandle *) fh timeSplitted: (NSInteger) timeSplitted splitTime: (NSInteger) st
{
    NSData * flag;
    NSData * buf;
    NSData * buf0;
    NSData * buf1;
    NSData * buf2;
    NSData * buf3;
    buf = [fh readDataOfLength: 1];
    if ([buf length] == 0)
    {
        NSDictionary *tires = [NSDictionary  dictionaryWithObjectsAndKeys :
                               [NSNumber numberWithInteger:0], @"tags" ,
                               nil];
        return tires;
    }
    
    NSMutableData * tagData = [NSMutableData dataWithData:buf];
    
    NSInteger tagType = [self oneByteNSDataToNSInteger: buf];
    
    NSInteger tagSize;
    buf0 = [fh readDataOfLength: 1];
    buf1 = [fh readDataOfLength: 1];
    buf2 = [fh readDataOfLength: 1];
    [tagData appendData:buf0];
    [tagData appendData:buf1];
    [tagData appendData:buf2];
    tagSize = ([self oneByteNSDataToNSInteger: buf0]
                    * 256 + [self oneByteNSDataToNSInteger:buf1] )
                    * 256 + [self oneByteNSDataToNSInteger:buf2];
    
    NSInteger timeStamp;
    buf1 = [fh readDataOfLength: 1];
    buf2 = [fh readDataOfLength: 1];
    buf3 = [fh readDataOfLength: 1];
    buf0 = [fh readDataOfLength: 1];
    //[tagData appendData:buf1];
    //[tagData appendData:buf2];
    //[tagData appendData:buf3];
    //[tagData appendData:buf0];
    timeStamp = ( ([self oneByteNSDataToNSInteger: buf0]
                    * 256 + [self oneByteNSDataToNSInteger:buf1] )
                    * 256 + [self oneByteNSDataToNSInteger:buf2] )
                    * 256 + [self oneByteNSDataToNSInteger:buf3]  ;
    
    buf0 = [fh readDataOfLength: 3];
    flag = [fh readDataOfLength: 1];
    buf1 = [fh readDataOfLength: tagSize-1];
    buf2 = [fh readDataOfLength: 4];
    
    //NSLog(@"tagId:%ld", tagId);
    //NSLog(@"tagType:%ld", tagType);
    //NSLog(@"tagSize:%ld", tagSize);
    //NSLog(@"timeStamp:%ld", timeStamp);
    //NSLog(@"tagDataLength:%lu", [tagData length]);
    //NSLog(@"tagData:%@", tagData);
    //NSLog(@"buf:%@", buf);
    
    NSInteger audioCodec = 0;
    NSInteger audioRate = 0;
    NSInteger audioSize = 0;
    NSInteger audioType = 0;
    NSInteger videoFrameType = 0;
    NSInteger videoCodec = 0;
    if (tagType == 8)
    {
        NSInteger audioflag = [self oneByteNSDataToNSInteger:flag];
        audioCodec = ( audioflag >> 4 ) & 0x0f;
        audioRate = ( audioflag >> 2 ) & 0x03;
        audioSize = ( audioflag >> 1 ) & 0x01;
        audioType = audioflag & 0x01;
    }
    else if (tagType == 9)
    {
        NSInteger videoflag = [self oneByteNSDataToNSInteger:flag];
        videoFrameType = ( videoflag >> 4 ) & 0x0f;
        videoCodec = videoflag & 0x0f;
    
    }
    
    NSInteger timeStampInFragFlv = timeStamp - timeSplitted;
    if (timeStampInFragFlv < 0 || (timeStampInFragFlv > st && videoFrameType == 1 ))
    {
        timeStampInFragFlv = 0;
    }
    [tagData appendData:[self IntToFlvTsData:timeStampInFragFlv]];
    [tagData appendData:buf0];
    [tagData appendData:flag];
    [tagData appendData:buf1];
    [tagData appendData:buf2];

    NSDictionary *flvTag = [NSDictionary  dictionaryWithObjectsAndKeys :
                            [NSNumber numberWithInteger:1], @"tags" ,
                            [NSNumber numberWithInteger:tagType], @"tagType" ,
                            [NSNumber numberWithInteger:tagSize], @"tagSize" ,
                            [NSNumber numberWithInteger:timeStamp], @"timeStamp" ,
                            [NSNumber numberWithInteger:audioCodec], @"audioCodec" ,
                            [NSNumber numberWithInteger:audioRate], @"audioRate" ,
                            [NSNumber numberWithInteger:audioSize], @"audioSize" ,
                            [NSNumber numberWithInteger:audioType], @"audioType" ,
                            [NSNumber numberWithInteger:videoFrameType], @"videoFrameType" ,
                            [NSNumber numberWithInteger:videoCodec], @"videoCodec" ,
                            tagData, @"tagData" ,
                            nil];
    return flvTag;
}

- (Boolean) valideDIR:(NSString *) path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if([fm isWritableFileAtPath:path])
    {
        return YES;
    }
    return NO;
}

- (Boolean) valideFLV:(NSString *) file
{
    NSFileHandle *fh;
    NSData *data;
    NSData *flvHeader = [@"FLV\1\5\0\0\0\t\0\0\0\0" dataUsingEncoding:NSUTF8StringEncoding];;
    
    fh = [NSFileHandle fileHandleForReadingAtPath: file];
    
    if (fh == nil)
    {
        return NO;
    }
    
    data = [fh readDataOfLength: 13];
    [fh closeFile];
    
    //NSLog(@"%@", flvHeader);
    if ([data isEqualToData:flvHeader])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (NSString *) file_selecter:(NSString *)type
{
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    NSArray *fileTypesArray;
    fileTypesArray = [NSArray arrayWithObjects:@"flv", nil];
    [openDlg setAllowedFileTypes:fileTypesArray];
    [openDlg setAllowsMultipleSelection:NO];
    
    if([type isEqualToString:@"dir"])
    {
        [openDlg setCanChooseFiles:NO];
        [openDlg setCanChooseDirectories:YES];
    }
    else if([type isEqualToString:@"file"])
    {
        [openDlg setCanChooseFiles:YES];
        [openDlg setCanChooseDirectories:NO];
    }
    else
    {
        return @"";
    }
    
    if ( [openDlg runModal] == NSOKButton ) {
        NSArray *files = [openDlg URLs];
        return [[files objectAtIndex:0] path];
    }
    
    return @"";
}

- (NSInteger) oneByteNSDataToNSInteger:(NSData *) data
{
    unsigned char bytes[1];
    [data getBytes:bytes length:1];
    NSInteger n = (int)bytes[0];
    //NSInteger n = (int)bytes[0] << 24;
    //n |= (int)bytes[1] << 16;
    //n |= (int)bytes[2] << 8;
    //n |= (int)bytes[3];
    return n;
}

- (NSData *) IntToFlvTsData:(NSInteger)ts
{
    Byte *byteData = (Byte*)malloc(4);
    byteData[2] = ts & 0xff;
    byteData[1] = (ts & 0xff00) >> 8;
    byteData[0] = (ts & 0xff0000) >> 16;
    byteData[3] = (ts & 0xff000000) >> 24;
    //byteData[3] = ts & 0xff;
    //byteData[2] = (ts & 0xff00) >> 8;
    //byteData[1] = (ts & 0xff0000) >> 16;
    //byteData[0] = (ts & 0xff000000) >> 24;
    NSData * result = [NSData dataWithBytes:byteData length:4];
    free(byteData);
    //NSLog(@"result=%@",result);
    return (NSData*)result;
}



@end
