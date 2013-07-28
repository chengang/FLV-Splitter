//
//  chengangAppDelegate.h
//  flvsplitter
//
//  Created by 陈 钢 on 13-6-4.
//  Copyright (c) 2013年 陈 钢. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface chengangAppDelegate : NSObject <NSApplicationDelegate>
{
    IBOutlet NSTextField * filename;
    IBOutlet NSTextField * outputDir;
    IBOutlet NSTextField * splitTime;
    IBOutlet NSTextField * valideFlvLabel;
    IBOutlet NSTextField * valideDirLabel;
    IBOutlet NSTextField * successLabel;
    IBOutlet NSTextField * failLabel;
}

@property (assign) IBOutlet NSWindow *window;


-(IBAction)select_file:(id)sender;
-(IBAction)select_output:(id)sender;
-(IBAction)split_it:(id)sender;


@end
