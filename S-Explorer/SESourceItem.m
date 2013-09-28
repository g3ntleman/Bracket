//
//  BRSourceItem.m
//  S-Explorer
//
//  Created by Dirk Theisen on 14.06.13.
//  Copyright (c) 2013 Cocoanuts. All rights reserved.
//

#import "SESourceItem.h"

@implementation SESourceItem {
    NSString* path;
    NSMutableArray* children;
    BOOL isDir;
}

@synthesize parent;
@synthesize content;


- (id) initWithPath: (NSString*) aPath parent: (SESourceItem*) parentItem {

    if (self = [self init]) {
        if (parentItem) {
            path = [[aPath lastPathComponent] copy];
            parent = parentItem;
        } else {
            path = aPath;
        }
        isDir = YES; // will be checked in -children
    }
    return self;
}


- (id) initWithFileURL: (NSURL*) aURL {
    return [self initWithPath: aURL.path parent: nil];
}

- (IBAction) saveDocument: (id) sender {
    if (self.isDocumentEdited) {
        [super saveDocument: sender];
    }
}


- (NSTextStorage*) content {
    if (! content) {
        NSError* readError = nil;
        [self readFromURL: [NSURL fileURLWithPath: self.absolutePath] ofType: @"public.text" error:&readError];
        _lastError = readError;
    }
    return content;
}

- (void) enumerateAllUsingBlock: (void (^)(SESourceItem* item, BOOL *stop)) block stop: (BOOL*) stopPtr {
    block(self, stopPtr);
    
    for (SESourceItem* child in self.children) {
        if (*stopPtr) {
            break;
        }
        [child enumerateAllUsingBlock: block stop: stopPtr];
    }
}

- (void) enumerateAllUsingBlock: (void (^)(SESourceItem* item, BOOL *stop)) block {
    BOOL stop = NO;
    [self enumerateAllUsingBlock:block stop: &stop];
}

- (BOOL) isTextItem {
    
    BOOL result = YES;
    NSString* extension = path.pathExtension;
    if (extension.length) {
        // If the UTI is any kind of text (RTF, plain text, Unicode, and so forth), the function UTTypeConformsTo returns true.
        CFStringRef itemUTI = UTTypeCreatePreferredIdentifierForTag (kUTTagClassFilenameExtension, (__bridge CFStringRef)(extension), NULL);

        
        result = UTTypeConformsTo(itemUTI, CFSTR("public.text"));
        CFRelease(itemUTI);
     }
    return result; // should we cache the result?
}

- (BOOL) readFromURL: (NSURL*) absoluteURL
              ofType: (NSString*) typeName
               error: (NSError**) outError {
    
    NSString* contentString = [NSString stringWithContentsOfURL:absoluteURL encoding:NSUTF8StringEncoding error: outError];
    if (contentString) {
        content = [[NSTextStorage alloc] initWithString: contentString];
    }
    self.fileType = typeName;
    return contentString != nil;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    BOOL result = [self.content.string writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error: outError];
    return result;
}

- (SESourceItem*) childItemWithName: (NSString*) name {
    for (SESourceItem* child in self.children) {
        if ([child.relativePath isEqualToString: name]) {
            return child;
        }
    }
    return nil;
}

- (SESourceItem*) childWithPath: (NSString*) aPath {
    NSArray* pathComponents = [aPath pathComponents];
    SESourceItem* current = self;
    for (NSString* name in pathComponents) {
        current = [current childItemWithName: name];
        if (! current) return nil;
    }
    return current;
}


/** 
  * Creates, caches, and returns the array of children SESourceItem objects.
  * Loads children incrementally. Returns nil for file items that cannot have children.
  **/
- (NSArray *)children {
    
    if (! isDir) {
        return nil;
    }
    
    if (children == nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString* fullPath = self.absolutePath;
        BOOL valid;
        
        valid = [fileManager fileExistsAtPath: fullPath isDirectory: &isDir];
        
        if (valid && isDir) {
            NSArray *array = [fileManager contentsOfDirectoryAtPath: fullPath error:NULL];
                        
            children = [[NSMutableArray alloc] initWithCapacity: array.count];
            
            for (NSString* childPath in array) {
                if (! [childPath hasPrefix: @"."]) {
                    SESourceItem* newChild = [[[self class] alloc] initWithPath: childPath parent: self];
                    [children addObject: newChild];
                }
            }
            children = [children copy]; // make immutable
        }
    }
    return children;
}


- (NSString*) relativePath {
    if (parent == nil) {
        return @"";
    }
    
    return path;
}

/**
 * Returns the path relative to the root parent. For the root item, returns the empty string.
 */
- (NSString*) longRelativePath {
    if (! parent) {
        return @"";
    }
    return [[parent longRelativePath] stringByAppendingPathComponent: path];
}

- (NSString*) absolutePath {
    // If no parent, return path
    if (parent == nil) {
        return path;
    }
    
    // recurse up the hierarchy, prepending each parent’s path
    return [parent.absolutePath stringByAppendingPathComponent:path];
}

- (NSURL*) fileURL {
    return [NSURL fileURLWithPath: self.absolutePath];
}

- (void) setFileURL:(NSURL *)url {
    // File URLs cannot be changed. Create a new instance instead!
    NSParameterAssert([url isEqual: self.fileURL]);
}

- (NSString*) description {
    return [NSString stringWithFormat: @"%@ @ '%@'", [super description], self.absolutePath];
}

- (NSArray*) sortedItemsWithPathExtension: (NSString*) pathExtension {
    NSMutableArray* result = [[NSMutableArray alloc] init];
    [self enumerateAllUsingBlock:^(SESourceItem *item, BOOL *stop) {
        if ([item.relativePath.pathExtension compare: pathExtension options: NSCaseInsensitiveSearch] == NSOrderedSame) {
            [result addObject: item];
        }
    }];
    [result sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[obj1 relativePath] compare: [obj2 relativePath] options: NSCaseInsensitiveSearch];
    }];
    
    return result;
}

@end

@implementation SESourceItem (PB)

- (NSArray*) writableTypesForPasteboard: (NSPasteboard*) pasteboard {
    return @[(NSString *)kPasteboardTypeFileURLPromise, NSPasteboardTypeString];
}


/* Returns the appropriate property list object for the provided type.  This will commonly be the NSData for that data type.  However, if this method returns either a string, or any other property-list type, the pasteboard will automatically convert these items to the correct NSData format required for the pasteboard.
 */
- (id) pasteboardPropertyListForType: (NSString*) type {
    
    if (type == NSPasteboardTypeString) {
        return self.absolutePath;
    }
    NSURL* url = [NSURL fileURLWithPath: self.absolutePath];
    //NSLog(@"pasteboardPropertyListForType %@ is %@", type, url);
    return url.absoluteString;
}


@end