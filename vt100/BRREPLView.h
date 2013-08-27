//
//  OPTerminalView.h
//  S-Explorer
//
//  Created by Dirk Theisen on 09.05.13.
//  Copyright (c) 2013 Cocoanuts. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "SEEditorTextView.h"

extern NSString* BKTextCommandAttributeName;


//@protocol BRREPLDelegate <NSObject>
//
//- (void) commitCommand: (NSString*) command;
//- (NSString*) previousCommand; // may return nil
//- (NSString*) nextCommand; // max return nil
//
//@end

@interface BRREPLView : SEEditorTextView


@property (readonly) NSDictionary* interpreterAttributes;
@property (readonly) NSDictionary* commandAttributes;

@property (strong, nonatomic) NSFont* font;

- (BOOL) isCommandMode;

@end

