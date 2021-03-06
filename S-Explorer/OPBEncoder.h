
#import <Foundation/Foundation.h>

@class OPBEncoder;

@protocol OPBencoding <NSObject>

- (void) encodeWithBencoder:(OPBEncoder*) encoder;
- (instancetype) initWithBencoder:(OPBEncoder*) decoder;

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


//  BEncoding
//
//  This class is not intended to be instantiated. Its a 'utility' class, and
//  as such you simply call the class methods as required when you need them.
//
//  The OPBEncoder class can encode and decode data to and from bencoded byte
//  data as defined here: https://wiki.theory.org/BitTorrentSpecification#Bencoding

@interface OPBEncoder : NSObject 

@property (readonly, nonatomic) NSUInteger offset;
@property (strong, nonatomic) NSData* decodingData;
@property (nonatomic) BOOL mutableContainers;

// Encoding:
@property (strong, readonly) NSData* encodingData;


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

- (NSData*) encodedDataFromObject: (id<OPBencoding>) object;

+ (instancetype) decoderForData: (NSData*) sourceData mutableContainers: (BOOL) mutable;
+ (instancetype) decoderForData: (NSData*) sourceData;

- (id <OPBencoding>) objectFromEncodedData: (NSData*) sourceData;

- (id) decodeObject;


@end

