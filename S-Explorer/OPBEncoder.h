
#import <Foundation/Foundation.h>

@class OPBEncoder;

@protocol OPBencoding <NSObject>

- (void) encodeWithBencoder:(OPBEncoder*) encoder;
- (id) initWithBencoder:(OPBEncoder*) decoder;

@end

@interface NSString (OPBEncodingSupport) <OPBencoding>
@end
//@interface NSData (OPBEncodingSupport) <OPBencoding>
//@end
@interface NSNumber (OPBEncodingSupport) <OPBencoding>
@end
@interface NSArray (OPBEncodingSupport) <OPBencoding>
@end
@interface NSDictionary (OPBEncodingSupport) <OPBencoding>
@end

//typedef enum {
//	OPBEncodedStringType = -1,
//	OPBEncodedDataType = 0
//} OPBEncodedType;

//typedef OPBEncodedType(^OPTypeBlock)(NSArray*);

//  BEncoding
//
//  This class is not intended to be instantiated. Its a 'utility' class, and
//  as such you simply call the class methods as required when you need them.
//
//  The BEncoding class can encode and decode data to and from bencoded byte
//  data as defined here: http://wiki.theory.org/BitTorrentSpecification

@interface OPBEncoder : NSObject 

@property (readonly, nonatomic) NSUInteger offset;
@property (strong, nonatomic) NSData* decodingData;

// Encoding:
@property (strong, readonly) NSData* encodingData;



- (instancetype) initForDecoding;
//- (instancetype) initForDecodingWithTypeBlock: (OPBEncodedType (^)(NSArray* keyPath)) aTypeBlock;

- (instancetype) initForEncoding;

//  This method to returns an NSData object that contains the bencoded
//  representation of the object that you send. You can send complex structures
//  such as an NSDictionary that contains NSArrays, NSNumbers and NSStrings, and
//  the encoder will correctly serialise the data in the expected way.
//
//  Supports NSData, NSString, NSNumber, NSArray and NSDictionary objects.
//
//  NSStrings are encoded as NSData objects as there is no way to differentiate
//  between the two when decoding.
//
//  NSNumbers are encoded and decoded with their longLongValue.
//
//  NSDictionary keys must be NSStrings.


//  +(id)objectFromEncodedData:(NSData *)sourceData;
//
//  This method returns an NSObject of the type that is serialised in the bencoded
//  sourceData.
//
//  Bad data should not cause any problems, however if it is unable to deserialise
//  anything from the source, it may return a nil, which you need to check for.

+ (NSData*) encodedDataFromObject: (id <OPBencoding>) object;
+ (id <OPBencoding>) objectFromEncodedData: (NSData*) sourceData;

- (NSData*) encodeRootObject:(id <OPBencoding>) object;

- (void) encodeBytes: (const void *) byteaddr length: (NSUInteger) length;
- (id) decodeObject;


@end