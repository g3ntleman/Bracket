//
//  SEEditorTextView.h
//  S-Explorer
//
//  Created by Dirk Theisen on 20.08.13.
//  Copyright (c) 2013 Cocoanuts. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "SESchemeParser.h"

@interface SEEditorTextView : NSTextView 

@property (strong, nonatomic) IBOutlet NSPanel* gotoPanel;

@property (readonly) NSString* selectedString;

- (IBAction) expandSelection: (id) sender;
- (IBAction) contractSelection: (id) sender;
- (IBAction) selectSpecificLine: (id) sender;
- (IBAction) colorize: (id) sender;

- (void) colorizeRange: (NSRange) aRange;


- (NSRange) selectLineNumber: (NSUInteger) line;

+ (NSColor*) commentColor;
+ (NSColor*) stringColor;
+ (NSColor*) numberColor;

@end
