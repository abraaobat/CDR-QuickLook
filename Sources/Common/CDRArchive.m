#import "CDRArchive.h"

#import <zlib.h>

NSString * const CDRQuickLookErrorDomain = @"com.abraaobat.cdrquicklook.error";

static const NSUInteger CDRMaximumEmbeddedImageSize = 64 * 1024 * 1024;

static uint16_t CDRReadLE16(const uint8_t *bytes) {
    return (uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8);
}

static uint32_t CDRReadLE32(const uint8_t *bytes) {
    return (uint32_t)bytes[0]
        | ((uint32_t)bytes[1] << 8)
        | ((uint32_t)bytes[2] << 16)
        | ((uint32_t)bytes[3] << 24);
}

static uint32_t CDRReadBE32(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24)
        | ((uint32_t)bytes[1] << 16)
        | ((uint32_t)bytes[2] << 8)
        | (uint32_t)bytes[3];
}

static NSError *CDRError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:CDRQuickLookErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface CDRZipEntry : NSObject
@property(nonatomic) uint16_t method;
@property(nonatomic) uint32_t compressedSize;
@property(nonatomic) uint32_t uncompressedSize;
@property(nonatomic) uint32_t localHeaderOffset;
@end

@implementation CDRZipEntry
@end

@interface CDRArchive ()
@property(nonatomic, strong) NSData *fileData;
@property(nonatomic, strong, nullable) CDRZipEntry *thumbnailEntry;
@property(nonatomic, copy) NSArray<CDRZipEntry *> *pageEntries;
@property(nonatomic, strong, nullable) NSData *fallbackImageData;
@end

@implementation CDRArchive

+ (instancetype)archiveWithURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url
                                        options:NSDataReadingMappedIfSafe
                                          error:error];
    if (data == nil) {
        return nil;
    }

    CDRArchive *archive = [[self alloc] init];
    archive.fileData = data;
    archive.pageEntries = @[];

    NSError *zipError = nil;
    BOOL parsedZip = [archive parseZipDirectory:&zipError];
    if (!parsedZip || (archive.thumbnailEntry == nil && archive.pageEntries.count == 0)) {
        archive.fallbackImageData = [archive findEmbeddedRasterImage];
    }

    if (archive.thumbnailEntry == nil
        && archive.pageEntries.count == 0
        && archive.fallbackImageData == nil) {
        if (error != NULL) {
            *error = zipError ?: CDRError(2, @"O arquivo CDR não contém uma prévia incorporada compatível.");
        }
        return nil;
    }

    return archive;
}

- (NSUInteger)pageCount {
    if (self.pageEntries.count > 0) {
        return self.pageEntries.count;
    }
    return (self.thumbnailEntry != nil || self.fallbackImageData != nil) ? 1 : 0;
}

- (NSData *)thumbnailDataWithError:(NSError **)error {
    if (self.thumbnailEntry != nil) {
        return [self dataForEntry:self.thumbnailEntry error:error];
    }
    if (self.pageEntries.count > 0) {
        return [self dataForEntry:self.pageEntries.firstObject error:error];
    }
    return self.fallbackImageData;
}

- (NSData *)pageDataAtIndex:(NSUInteger)index error:(NSError **)error {
    if (self.pageEntries.count > 0) {
        if (index >= self.pageEntries.count) {
            if (error != NULL) {
                *error = CDRError(3, @"Página de prévia fora do intervalo.");
            }
            return nil;
        }
        return [self dataForEntry:self.pageEntries[index] error:error];
    }
    if (index == 0) {
        if (self.thumbnailEntry != nil) {
            return [self dataForEntry:self.thumbnailEntry error:error];
        }
        return self.fallbackImageData;
    }
    if (error != NULL) {
        *error = CDRError(3, @"Página de prévia fora do intervalo.");
    }
    return nil;
}

- (BOOL)parseZipDirectory:(NSError **)error {
    const uint8_t *bytes = self.fileData.bytes;
    NSUInteger length = self.fileData.length;
    if (length < 22) {
        if (error != NULL) {
            *error = CDRError(4, @"O arquivo é pequeno demais para ser um CDR moderno.");
        }
        return NO;
    }

    NSUInteger minimum = length > (0xFFFF + 22) ? length - (0xFFFF + 22) : 0;
    NSUInteger eocd = NSNotFound;
    for (NSUInteger cursor = length - 22;; cursor--) {
        if (CDRReadLE32(bytes + cursor) == 0x06054b50) {
            eocd = cursor;
            break;
        }
        if (cursor == minimum) {
            break;
        }
    }
    if (eocd == NSNotFound || eocd + 22 > length) {
        if (error != NULL) {
            *error = CDRError(5, @"O CDR não usa o contêiner ZIP esperado.");
        }
        return NO;
    }

    uint16_t entryCount = CDRReadLE16(bytes + eocd + 10);
    uint32_t centralSize = CDRReadLE32(bytes + eocd + 12);
    uint32_t centralOffset = CDRReadLE32(bytes + eocd + 16);
    if (entryCount == 0xFFFF || centralSize == 0xFFFFFFFF || centralOffset == 0xFFFFFFFF) {
        if (error != NULL) {
            *error = CDRError(6, @"Arquivos CDR ZIP64 ainda não são compatíveis.");
        }
        return NO;
    }
    if ((uint64_t)centralOffset + centralSize > length) {
        if (error != NULL) {
            *error = CDRError(7, @"O diretório interno do CDR está corrompido.");
        }
        return NO;
    }

    NSMutableDictionary<NSNumber *, CDRZipEntry *> *pages = [NSMutableDictionary dictionary];
    NSRegularExpression *pagePattern = [NSRegularExpression regularExpressionWithPattern:@"^previews/page([0-9]+)\\.png$"
                                                                                  options:NSRegularExpressionCaseInsensitive
                                                                                    error:nil];
    NSUInteger cursor = centralOffset;
    for (NSUInteger item = 0; item < entryCount; item++) {
        if (cursor + 46 > length || CDRReadLE32(bytes + cursor) != 0x02014b50) {
            if (error != NULL) {
                *error = CDRError(8, @"Uma entrada interna do CDR está corrompida.");
            }
            return NO;
        }

        uint16_t method = CDRReadLE16(bytes + cursor + 10);
        uint32_t compressedSize = CDRReadLE32(bytes + cursor + 20);
        uint32_t uncompressedSize = CDRReadLE32(bytes + cursor + 24);
        uint16_t nameLength = CDRReadLE16(bytes + cursor + 28);
        uint16_t extraLength = CDRReadLE16(bytes + cursor + 30);
        uint16_t commentLength = CDRReadLE16(bytes + cursor + 32);
        uint32_t localOffset = CDRReadLE32(bytes + cursor + 42);
        uint64_t next = (uint64_t)cursor + 46 + nameLength + extraLength + commentLength;
        if (next > length) {
            if (error != NULL) {
                *error = CDRError(9, @"Um nome de entrada interna ultrapassa o fim do arquivo.");
            }
            return NO;
        }

        NSData *nameData = [NSData dataWithBytes:bytes + cursor + 46 length:nameLength];
        NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
        if (name != nil) {
            CDRZipEntry *entry = [[CDRZipEntry alloc] init];
            entry.method = method;
            entry.compressedSize = compressedSize;
            entry.uncompressedSize = uncompressedSize;
            entry.localHeaderOffset = localOffset;

            if ([name caseInsensitiveCompare:@"previews/thumbnail.png"] == NSOrderedSame) {
                self.thumbnailEntry = entry;
            } else {
                NSTextCheckingResult *match = [pagePattern firstMatchInString:name
                                                                       options:0
                                                                         range:NSMakeRange(0, name.length)];
                if (match != nil && match.numberOfRanges == 2) {
                    NSString *numberText = [name substringWithRange:[match rangeAtIndex:1]];
                    NSInteger pageNumber = numberText.integerValue;
                    if (pageNumber > 0 && pageNumber <= 10000) {
                        pages[@(pageNumber)] = entry;
                    }
                }
            }
        }
        cursor = (NSUInteger)next;
    }

    NSArray<NSNumber *> *numbers = [[pages allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<CDRZipEntry *> *ordered = [NSMutableArray arrayWithCapacity:numbers.count];
    for (NSNumber *number in numbers) {
        [ordered addObject:pages[number]];
    }
    self.pageEntries = ordered;
    return YES;
}

- (NSData *)dataForEntry:(CDRZipEntry *)entry error:(NSError **)error {
    const uint8_t *bytes = self.fileData.bytes;
    NSUInteger length = self.fileData.length;
    uint64_t localOffset = entry.localHeaderOffset;
    if (localOffset + 30 > length || CDRReadLE32(bytes + localOffset) != 0x04034b50) {
        if (error != NULL) {
            *error = CDRError(10, @"O cabeçalho da imagem de prévia está corrompido.");
        }
        return nil;
    }

    uint16_t nameLength = CDRReadLE16(bytes + localOffset + 26);
    uint16_t extraLength = CDRReadLE16(bytes + localOffset + 28);
    uint64_t dataOffset = localOffset + 30 + nameLength + extraLength;
    uint64_t dataEnd = dataOffset + entry.compressedSize;
    if (dataEnd > length || entry.uncompressedSize > CDRMaximumEmbeddedImageSize) {
        if (error != NULL) {
            *error = CDRError(11, @"A imagem de prévia interna é inválida ou grande demais.");
        }
        return nil;
    }

    const uint8_t *source = bytes + dataOffset;
    if (entry.method == 0) {
        return [NSData dataWithBytes:source length:entry.compressedSize];
    }
    if (entry.method != 8 || entry.compressedSize > UINT_MAX || entry.uncompressedSize > UINT_MAX) {
        if (error != NULL) {
            *error = CDRError(12, @"O método de compressão da prévia não é compatível.");
        }
        return nil;
    }

    NSMutableData *output = [NSMutableData dataWithLength:entry.uncompressedSize];
    z_stream stream = {0};
    stream.next_in = (Bytef *)source;
    stream.avail_in = (uInt)entry.compressedSize;
    stream.next_out = output.mutableBytes;
    stream.avail_out = (uInt)entry.uncompressedSize;

    int status = inflateInit2(&stream, -MAX_WBITS);
    if (status == Z_OK) {
        status = inflate(&stream, Z_FINISH);
        inflateEnd(&stream);
    }
    if (status != Z_STREAM_END || stream.total_out != entry.uncompressedSize) {
        if (error != NULL) {
            *error = CDRError(13, @"Não foi possível descompactar a prévia incorporada.");
        }
        return nil;
    }
    return output;
}

- (NSData *)findEmbeddedRasterImage {
    const uint8_t *bytes = self.fileData.bytes;
    NSUInteger length = self.fileData.length;
    static const uint8_t pngSignature[8] = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};

    for (NSUInteger start = 0; start + 20 <= length; start++) {
        if (memcmp(bytes + start, pngSignature, sizeof(pngSignature)) != 0) {
            continue;
        }
        NSUInteger cursor = start + 8;
        while (cursor + 12 <= length && cursor - start <= CDRMaximumEmbeddedImageSize) {
            uint32_t chunkLength = CDRReadBE32(bytes + cursor);
            uint64_t next = (uint64_t)cursor + 12 + chunkLength;
            if (next > length || next - start > CDRMaximumEmbeddedImageSize) {
                break;
            }
            if (memcmp(bytes + cursor + 4, "IEND", 4) == 0) {
                return [NSData dataWithBytes:bytes + start length:(NSUInteger)(next - start)];
            }
            cursor = (NSUInteger)next;
        }
    }

    for (NSUInteger start = 0; start + 4 <= length; start++) {
        if (bytes[start] != 0xFF || bytes[start + 1] != 0xD8) {
            continue;
        }
        NSUInteger limit = MIN(length, start + CDRMaximumEmbeddedImageSize);
        for (NSUInteger cursor = start + 2; cursor + 1 < limit; cursor++) {
            if (bytes[cursor] == 0xFF && bytes[cursor + 1] == 0xD9) {
                return [NSData dataWithBytes:bytes + start length:cursor + 2 - start];
            }
        }
    }
    return nil;
}

@end
