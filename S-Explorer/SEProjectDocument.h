//
//  BRDocument.h
//  S-Explorer
//
//  Created by Dirk Theisen on 09.05.13.
//  Copyright (c) 2013 Cocoanuts. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "SEREPLViewController.h"
#import "SESyntaxParser.h"
#import "SESourceItem.h"
#import "SESourceEditorController.h"
#import "SEnREPL.h"
#import "SCEvents.h"

extern NSString* SEProjectDocumentType;

@class SESourceItem;

@interface SEProjectDocument : NSDocument <NSOutlineViewDataSource, NSOutlineViewDelegate, NSUserInterfaceValidations, NSTabViewDelegate, SCEventListenerProtocol>

@property (strong, nonatomic) SCEvents* pathWatcher;

@property (nonatomic, readonly) SEnREPL* nREPL;
@property (readonly, nonatomic) SEREPLViewController* topREPLController;
@property (readonly, nonatomic) NSDictionary* allREPLControllers;
@property (strong, nonatomic) IBOutlet NSTabView* replTabView;
@property (strong, nonatomic) IBOutlet NSView* sourceCellView;
@property (strong, nonatomic) IBOutlet NSImageView* sourceCellIconView;
@property (strong, nonatomic) IBOutlet NSTextField* sourceCellTextField;

@property (readonly) SESourceItem* projectFolderItem;
@property (strong, nonatomic) NSDictionary* tabbedSourceItems; // keys are NSNumbers, starting with @(0), values are SESourceItem objects.
@property (strong, nonatomic) IBOutlet NSTabView* sourceTabView;
@property (strong, nonatomic) IBOutlet NSOutlineView* sourceList;
@property (strong, readonly) NSMutableDictionary* projectSettings;
@property (strong, readonly) NSMutableDictionary* uiSettings;
@property (strong, nonatomic) IBOutlet SESourceEditorController* editorController; // Controls one SEEditorTextView, switching between tabs is done by setting a new sourceItem.

@property (strong, nonatomic) NSString* currentLanguage;
@property (strong, readonly) NSDictionary* languageDictionary;
@property (strong, readonly) SESourceItem* currentSourceItem;

- (NSMutableDictionary*) replSettingsForIdentifier: (NSString*) identifier;



- (void) saveProjectSettings;

// IBActions:

//- (IBAction) selectSourceTab: (id) sender;
- (IBAction) sourceTableAction: (id) sender;
- (IBAction) revertCurrentSourceItemToSaved: (id) sender;
- (IBAction) saveCurrentSourceItem: (id) sender;
- (IBAction) saveAllSourceItems: (id) sender;

- (IBAction) runProject: (id) sender;
- (IBAction) revealInFinder: (id) sender;
- (IBAction) newFile: (id) sender;


- (void) setSourceItem: (SESourceItem*) item forTabIndex: (NSUInteger) index;

- (void) startREPLServerAsNeccessary;

- (void) openSourceItem: (SESourceItem*) item;

@end