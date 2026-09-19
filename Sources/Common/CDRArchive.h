#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads the embedded preview images stored by modern CorelDRAW documents.
/// The archive is memory-mapped, so large .cdr files do not have to be copied
/// into the extension process just to obtain a small preview.
@interface CDRArchive : NSObject

+ (nullable instancetype)archiveWithURL:(NSURL *)url
                                  error:(NSError * _Nullable * _Nullable)error;

@property(nonatomic, readonly) NSUInteger pageCount;

- (nullable NSData *)thumbnailDataWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)pageDataAtIndex:(NSUInteger)index
                               error:(NSError * _Nullable * _Nullable)error;

@end

FOUNDATION_EXPORT NSString * const CDRQuickLookErrorDomain;

NS_ASSUME_NONNULL_END
