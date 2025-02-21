/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the plugins of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qglobal.h"

#include <sys/param.h>

#if defined(Q_OS_OSX)
#import <AppKit/AppKit.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#elif defined(QT_PLATFORM_UIKIT)
#import <UIKit/UIFont.h>
#endif

#include "qcoretextfontdatabase_p.h"
#include "qfontengine_coretext_p.h"
#include <QtCore/QSettings>
#include <QtCore/QtEndian>
#ifndef QT_NO_FREETYPE
#include <QtFontDatabaseSupport/private/qfontengine_ft_p.h>
#endif

QT_BEGIN_NAMESPACE

// this could become a list of all languages used for each writing
// system, instead of using the single most common language.
static const char *languageForWritingSystem[] = {
    0,     // Any
    "en",  // Latin
    "el",  // Greek
    "ru",  // Cyrillic
    "hy",  // Armenian
    "he",  // Hebrew
    "ar",  // Arabic
    "syr", // Syriac
    "div", // Thaana
    "hi",  // Devanagari
    "bn",  // Bengali
    "pa",  // Gurmukhi
    "gu",  // Gujarati
    "or",  // Oriya
    "ta",  // Tamil
    "te",  // Telugu
    "kn",  // Kannada
    "ml",  // Malayalam
    "si",  // Sinhala
    "th",  // Thai
    "lo",  // Lao
    "bo",  // Tibetan
    "my",  // Myanmar
    "ka",  // Georgian
    "km",  // Khmer
    "zh-Hans", // SimplifiedChinese
    "zh-Hant", // TraditionalChinese
    "ja",  // Japanese
    "ko",  // Korean
    "vi",  // Vietnamese
    0, // Symbol
    "sga", // Ogham
    "non", // Runic
    "man" // N'Ko
};
enum { LanguageCount = sizeof(languageForWritingSystem) / sizeof(const char *) };

#ifdef Q_OS_OSX
static NSInteger languageMapSort(id obj1, id obj2, void *context)
{
    NSArray *map1 = (NSArray *) obj1;
    NSArray *map2 = (NSArray *) obj2;
    NSArray *languages = (NSArray *) context;

    NSString *lang1 = [map1 objectAtIndex: 0];
    NSString *lang2 = [map2 objectAtIndex: 0];

    return [languages indexOfObject: lang1] - [languages indexOfObject: lang2];
}
#endif

QCoreTextFontDatabase::QCoreTextFontDatabase()
    : m_hasPopulatedAliases(false)
{
#ifdef Q_OS_MACX
    QSettings appleSettings(QLatin1String("apple.com"));
    QVariant appleValue = appleSettings.value(QLatin1String("AppleAntiAliasingThreshold"));
    if (appleValue.isValid())
        QCoreTextFontEngine::antialiasingThreshold = appleValue.toInt();

    /*
        font_smoothing = 0 means no smoothing, while 1-3 means subpixel
        antialiasing with different hinting styles (but we don't care about the
        exact value, only if subpixel rendering is available or not)
    */
    int font_smoothing = 0;
    appleValue = appleSettings.value(QLatin1String("AppleFontSmoothing"));
    if (appleValue.isValid()) {
        font_smoothing = appleValue.toInt();
    } else {
        // non-Apple displays do not provide enough information about subpixel rendering so
        // draw text with cocoa and compare pixel colors to see if subpixel rendering is enabled
        int w = 10;
        int h = 10;
        NSRect rect = NSMakeRect(0.0, 0.0, w, h);
        NSImage *fontImage = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];

        [fontImage lockFocus];

        [[NSColor whiteColor] setFill];
        NSRectFill(rect);

        NSString *str = @"X\\";
        NSFont *font = [NSFont fontWithName:@"Helvetica" size:10.0];
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setObject:font forKey:NSFontAttributeName];
        [attrs setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];

        [str drawInRect:rect withAttributes:attrs];

        NSBitmapImageRep *nsBitmapImage = [[NSBitmapImageRep alloc] initWithFocusedViewRect:rect];

        [fontImage unlockFocus];

        float red, green, blue;
        for (int x = 0; x < w; x++) {
            for (int y = 0; y < h; y++) {
                NSColor *pixelColor = [nsBitmapImage colorAtX:x y:y];
                red = [pixelColor redComponent];
                green = [pixelColor greenComponent];
                blue = [pixelColor blueComponent];
                if (red != green || red != blue)
                    font_smoothing = 1;
            }
        }

        [nsBitmapImage release];
        [fontImage release];
    }
    QCoreTextFontEngine::defaultGlyphFormat = (font_smoothing > 0
                                               ? QFontEngine::Format_A32
                                               : QFontEngine::Format_A8);
#else
    QCoreTextFontEngine::defaultGlyphFormat = QFontEngine::Format_A8;
#endif
}

QCoreTextFontDatabase::~QCoreTextFontDatabase()
{
    for (CTFontDescriptorRef ref : qAsConst(m_systemFontDescriptors))
        CFRelease(ref);
}

static CFArrayRef availableFamilyNames()
{
#if QT_DARWIN_PLATFORM_SDK_EQUAL_OR_ABOVE(1060, 100000, 100000, 30000)
    if (&CTFontManagerCopyAvailableFontFamilyNames)
        return CTFontManagerCopyAvailableFontFamilyNames();
#endif
#if defined(QT_PLATFORM_UIKIT)
    CFMutableArrayRef familyNames = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, (CFArrayRef)[UIFont familyNames]);
    CFArrayAppendValue(familyNames, CFSTR(".PhoneFallback"));
    return familyNames;
#endif
    Q_UNREACHABLE();
}

void QCoreTextFontDatabase::populateFontDatabase()
{
    QCFType<CFArrayRef> familyNames = availableFamilyNames();
    for (NSString *familyName in familyNames.as<const NSArray *>())
        QPlatformFontDatabase::registerFontFamily(QString::fromNSString(familyName));

    // Force creating the theme fonts to get the descriptors in m_systemFontDescriptors
    if (m_themeFonts.isEmpty())
        (void)themeFonts();

    Q_FOREACH (CTFontDescriptorRef fontDesc, m_systemFontDescriptors)
        populateFromDescriptor(fontDesc);

    Q_ASSERT(!m_hasPopulatedAliases);
}

bool QCoreTextFontDatabase::populateFamilyAliases()
{
#if defined(Q_OS_MACOS)
    if (m_hasPopulatedAliases)
        return false;

    QCFType<CFArrayRef> familyNames = availableFamilyNames();
    for (NSString *familyName in familyNames.as<const NSArray *>()) {
        NSFontManager *fontManager = [NSFontManager sharedFontManager];
        NSString *localizedFamilyName = [fontManager localizedNameForFamily:familyName face:nil];
        if (![localizedFamilyName isEqual:familyName]) {
            QPlatformFontDatabase::registerAliasToFontFamily(
                QString::fromNSString(familyName),
                QString::fromNSString(localizedFamilyName));
        }
    }
    m_hasPopulatedAliases = true;
    return true;
#else
    return false;
#endif
}

void QCoreTextFontDatabase::populateFamily(const QString &familyName)
{
    QCFType<CFMutableDictionaryRef> attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(attributes, kCTFontFamilyNameAttribute, QCFString(familyName));
    QCFType<CTFontDescriptorRef> nameOnlyDescriptor = CTFontDescriptorCreateWithAttributes(attributes);

    // A single family might match several different fonts with different styles eg.
    QCFType<CFArrayRef> matchingFonts = (CFArrayRef) CTFontDescriptorCreateMatchingFontDescriptors(nameOnlyDescriptor, 0);
    if (!matchingFonts) {
        qWarning() << "QCoreTextFontDatabase: Found no matching fonts for family" << familyName;
        return;
    }

    const int numFonts = CFArrayGetCount(matchingFonts);
    for (int i = 0; i < numFonts; ++i)
        populateFromDescriptor(CTFontDescriptorRef(CFArrayGetValueAtIndex(matchingFonts, i)), familyName);
}

void QCoreTextFontDatabase::invalidate()
{
    m_hasPopulatedAliases = false;
}

struct FontDescription {
    QCFString familyName;
    QCFString postscriptName;
    QCFString styleName;
    QString foundryName;
    QFont::Weight weight;
    QFont::Style style;
    QFont::Stretch stretch;
    int pixelSize;
    bool fixedPitch;
    QSupportedWritingSystems writingSystems;
};

#ifndef QT_NO_DEBUG_STREAM
Q_DECL_UNUSED static inline QDebug operator<<(QDebug debug, const FontDescription &fd)
{
    QDebugStateSaver saver(debug);
    return debug.nospace() << "FontDescription("
        << "familyName=" << QString(fd.familyName)
        << ", postscriptName=" << QString(fd.postscriptName)
        << ", styleName=" << QString(fd.styleName)
        << ", foundry=" << fd.foundryName
        << ", weight=" << fd.weight
        << ", style=" << fd.style
        << ", stretch=" << fd.stretch
        << ", pixelSize=" << fd.pixelSize
        << ", fixedPitch=" << fd.fixedPitch
        << ", writingSystems=" << fd.writingSystems
    << ")";
}
#endif

static void getFontDescription(CTFontDescriptorRef font, FontDescription *fd)
{
    QCFType<CFDictionaryRef> styles = (CFDictionaryRef) CTFontDescriptorCopyAttribute(font, kCTFontTraitsAttribute);

    fd->foundryName = QStringLiteral("CoreText");
    fd->familyName = (CFStringRef) CTFontDescriptorCopyAttribute(font, kCTFontFamilyNameAttribute);
    fd->postscriptName = (CFStringRef) CTFontDescriptorCopyAttribute(font, kCTFontNameAttribute);
    fd->styleName = (CFStringRef)CTFontDescriptorCopyAttribute(font, kCTFontStyleNameAttribute);
    fd->weight = QFont::Normal;
    fd->style = QFont::StyleNormal;
    fd->stretch = QFont::Unstretched;
    fd->fixedPitch = false;

    if (QCFType<CTFontRef> tempFont = CTFontCreateWithFontDescriptor(font, 0.0, 0)) {
        uint tag = MAKE_TAG('O', 'S', '/', '2');
        CTFontRef tempFontRef = tempFont;
        void *userData = reinterpret_cast<void *>(&tempFontRef);
        uint length = 128;
        QVarLengthArray<uchar, 128> os2Table(length);
        if (QCoreTextFontEngine::ct_getSfntTable(userData, tag, os2Table.data(), &length) && length >= 86) {
            if (length > uint(os2Table.length())) {
                os2Table.resize(length);
                if (!QCoreTextFontEngine::ct_getSfntTable(userData, tag, os2Table.data(), &length))
                    Q_UNREACHABLE();
                Q_ASSERT(length >= 86);
            }
            quint32 unicodeRange[4] = {
                qFromBigEndian<quint32>(os2Table.data() + 42),
                qFromBigEndian<quint32>(os2Table.data() + 46),
                qFromBigEndian<quint32>(os2Table.data() + 50),
                qFromBigEndian<quint32>(os2Table.data() + 54)
            };
            quint32 codePageRange[2] = {
                qFromBigEndian<quint32>(os2Table.data() + 78),
                qFromBigEndian<quint32>(os2Table.data() + 82)
            };
            fd->writingSystems = QPlatformFontDatabase::writingSystemsFromTrueTypeBits(unicodeRange, codePageRange);
        }
    }

    if (styles) {
        if (CFNumberRef weightValue = (CFNumberRef) CFDictionaryGetValue(styles, kCTFontWeightTrait)) {
            double normalizedWeight;
            if (CFNumberGetValue(weightValue, kCFNumberFloat64Type, &normalizedWeight))
                fd->weight = QCoreTextFontEngine::qtWeightFromCFWeight(float(normalizedWeight));
        }
        if (CFNumberRef italic = (CFNumberRef) CFDictionaryGetValue(styles, kCTFontSlantTrait)) {
            double d;
            if (CFNumberGetValue(italic, kCFNumberDoubleType, &d)) {
                if (d > 0.0)
                    fd->style = QFont::StyleItalic;
            }
        }
        if (CFNumberRef symbolic = (CFNumberRef) CFDictionaryGetValue(styles, kCTFontSymbolicTrait)) {
            int d;
            if (CFNumberGetValue(symbolic, kCFNumberSInt32Type, &d)) {
                if (d & kCTFontMonoSpaceTrait)
                    fd->fixedPitch = true;
                if (d & kCTFontExpandedTrait)
                    fd->stretch = QFont::Expanded;
                else if (d & kCTFontCondensedTrait)
                    fd->stretch = QFont::Condensed;
            }
        }
    }

    if (QCFType<CFNumberRef> size = (CFNumberRef) CTFontDescriptorCopyAttribute(font, kCTFontSizeAttribute)) {
        if (CFNumberIsFloatType(size)) {
            double d;
            CFNumberGetValue(size, kCFNumberDoubleType, &d);
            fd->pixelSize = d;
        } else {
            CFNumberGetValue(size, kCFNumberIntType, &fd->pixelSize);
        }
    }

    if (QCFType<CFArrayRef> languages = (CFArrayRef) CTFontDescriptorCopyAttribute(font, kCTFontLanguagesAttribute)) {
        CFIndex length = CFArrayGetCount(languages);
        for (int i = 1; i < LanguageCount; ++i) {
            if (!languageForWritingSystem[i])
                continue;
            QCFString lang = CFStringCreateWithCString(NULL, languageForWritingSystem[i], kCFStringEncodingASCII);
            if (CFArrayContainsValue(languages, CFRangeMake(0, length), lang))
                fd->writingSystems.setSupported(QFontDatabase::WritingSystem(i));
        }
    }
}

void QCoreTextFontDatabase::populateFromDescriptor(CTFontDescriptorRef font, const QString &familyName)
{
    FontDescription fd;
    getFontDescription(font, &fd);

    // Note: The familyName we are registering, and the family name of the font descriptor, may not
    // match, as CTFontDescriptorCreateMatchingFontDescriptors will return descriptors for replacement
    // fonts if a font family does not have any fonts available on the system.
    QString family = !familyName.isNull() ? familyName : static_cast<QString>(fd.familyName);

    CFRetain(font);
    QPlatformFontDatabase::registerFont(family, fd.postscriptName, fd.styleName, fd.foundryName, fd.weight, fd.style, fd.stretch,
            true /* antialiased */, true /* scalable */,
            fd.pixelSize, fd.fixedPitch, fd.writingSystems, (void *) font);
}

static NSString * const kQtFontDataAttribute = @"QtFontDataAttribute";

template <typename T>
T *descriptorAttribute(CTFontDescriptorRef descriptor, CFStringRef name)
{
    return [static_cast<T *>(CTFontDescriptorCopyAttribute(descriptor, name)) autorelease];
}

void QCoreTextFontDatabase::releaseHandle(void *handle)
{
    CTFontDescriptorRef descriptor = static_cast<CTFontDescriptorRef>(handle);
    if (NSValue *fontDataValue = descriptorAttribute<NSValue>(descriptor, (CFStringRef)kQtFontDataAttribute)) {
        QByteArray *fontData = static_cast<QByteArray *>(fontDataValue.pointerValue);
        delete fontData;
    }
    CFRelease(descriptor);
}

extern CGAffineTransform qt_transform_from_fontdef(const QFontDef &fontDef);

template <>
QFontEngine *QCoreTextFontDatabaseEngineFactory<QCoreTextFontEngine>::fontEngine(const QFontDef &fontDef, void *usrPtr)
{
    QCFType<CTFontDescriptorRef> descriptor = QCFType<CTFontDescriptorRef>::constructFromGet(
        static_cast<CTFontDescriptorRef>(usrPtr));

    // CoreText will sometimes invalidate information in font descriptors that refer
    // to system fonts in certain function calls or application states. While the descriptor
    // looks the same from the outside, some internal plumbing is different, causing the results
    // of creating CTFonts from those descriptors unreliable. The work-around for this
    // is to copy the attributes of those descriptors each time we make a new CTFont
    // from them instead of referring to the original, as that may trigger the CoreText bug.
    if (m_systemFontDescriptors.contains(descriptor)) {
        QCFType<CFDictionaryRef> attributes = CTFontDescriptorCopyAttributes(descriptor);
        descriptor = CTFontDescriptorCreateWithAttributes(attributes);
    }

    // Since we do not pass in the destination DPI to CoreText when making
    // the font, we need to pass in a point size which is scaled to include
    // the DPI. The default DPI for the screen is 72, thus the scale factor
    // is destinationDpi / 72, but since pixelSize = pointSize / 72 * dpi,
    // the pixelSize is actually the scaled point size for the destination
    // DPI, and we can use that directly.
    qreal scaledPointSize = fontDef.pixelSize;

    CGAffineTransform matrix = qt_transform_from_fontdef(fontDef);
    if (QCFType<CTFontRef> font = CTFontCreateWithFontDescriptor(descriptor, scaledPointSize, &matrix))
        return new QCoreTextFontEngine(font, fontDef);

    return nullptr;
}

#ifndef QT_NO_FREETYPE
template <>
QFontEngine *QCoreTextFontDatabaseEngineFactory<QFontEngineFT>::fontEngine(const QFontDef &fontDef, void *usrPtr)
{
    CTFontDescriptorRef descriptor = static_cast<CTFontDescriptorRef>(usrPtr);

    if (NSValue *fontDataValue = descriptorAttribute<NSValue>(descriptor, (CFStringRef)kQtFontDataAttribute)) {
        QByteArray *fontData = static_cast<QByteArray *>(fontDataValue.pointerValue);
        return QFontEngineFT::create(*fontData, fontDef.pixelSize,
            static_cast<QFont::HintingPreference>(fontDef.hintingPreference));
    } else if (NSURL *url = descriptorAttribute<NSURL>(descriptor, kCTFontURLAttribute)) {
        Q_ASSERT(url.fileURL);
        QFontEngine::FaceId faceId;
        faceId.filename = QString::fromNSString(url.path).toUtf8();
        return QFontEngineFT::create(fontDef, faceId);
    }
    Q_UNREACHABLE();
}
#endif

template <class T>
QFontEngine *QCoreTextFontDatabaseEngineFactory<T>::fontEngine(const QByteArray &fontData, qreal pixelSize, QFont::HintingPreference hintingPreference)
{
    return T::create(fontData, pixelSize, hintingPreference);
}

// Explicitly instantiate so that we don't need the plugin to involve FreeType
template class QCoreTextFontDatabaseEngineFactory<QCoreTextFontEngine>;
#ifndef QT_NO_FREETYPE
template class QCoreTextFontDatabaseEngineFactory<QFontEngineFT>;
#endif

QFont::StyleHint styleHintFromNSString(NSString *style)
{
    if ([style isEqual: @"sans-serif"])
        return QFont::SansSerif;
    else if ([style isEqual: @"monospace"])
        return QFont::Monospace;
    else if ([style isEqual: @"cursive"])
        return QFont::Cursive;
    else if ([style isEqual: @"serif"])
        return QFont::Serif;
    else if ([style isEqual: @"fantasy"])
        return QFont::Fantasy;
    else // if ([style isEqual: @"default"])
        return QFont::AnyStyle;
}

#ifdef Q_OS_OSX
static QString familyNameFromPostScriptName(NSString *psName)
{
    QCFType<CTFontDescriptorRef> fontDescriptor = (CTFontDescriptorRef) CTFontDescriptorCreateWithNameAndSize((CFStringRef)psName, 12.0);
    QCFString familyName = (CFStringRef) CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontFamilyNameAttribute);
    QString name = QString::fromCFString(familyName);
    if (name.isEmpty())
        qWarning() << "QCoreTextFontDatabase: Failed to resolve family name for PostScript name " << QString::fromCFString((CFStringRef)psName);

    return name;
}
#endif

static void addExtraFallbacks(QStringList *fallbackList)
{
#if defined(Q_OS_MACOS)
    // Since we are only returning a list of default fonts for the current language, we do not
    // cover all unicode completely. This was especially an issue for some of the common script
    // symbols such as mathematical symbols, currency or geometric shapes. To minimize the risk
    // of missing glyphs, we add Arial Unicode MS as a final fail safe, since this covers most
    // of Unicode 2.1.
    if (!fallbackList->contains(QStringLiteral("Arial Unicode MS")))
        fallbackList->append(QStringLiteral("Arial Unicode MS"));
    // Since some symbols (specifically Braille) are not in Arial Unicode MS, we
    // add Apple Symbols to cover those too.
    if (!fallbackList->contains(QStringLiteral("Apple Symbols")))
        fallbackList->append(QStringLiteral("Apple Symbols"));
#endif
}

QStringList QCoreTextFontDatabase::fallbacksForFamily(const QString &family, QFont::Style style, QFont::StyleHint styleHint, QChar::Script script) const
{
    Q_UNUSED(style);
    Q_UNUSED(script);

    QMacAutoReleasePool pool;

    static QHash<QString, QStringList> fallbackLists;

    if (!family.isEmpty()) {
        QCFType<CFMutableDictionaryRef> attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionaryAddValue(attributes, kCTFontFamilyNameAttribute, QCFString(family));
        if (QCFType<CTFontDescriptorRef> fontDescriptor = CTFontDescriptorCreateWithAttributes(attributes)) {
            if (QCFType<CTFontRef> font = CTFontCreateWithFontDescriptor(fontDescriptor, 12.0, 0)) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSArray *languages = [defaults stringArrayForKey: @"AppleLanguages"];

                QCFType<CFArrayRef> cascadeList = (CFArrayRef) CTFontCopyDefaultCascadeListForLanguages(font, (CFArrayRef) languages);
                if (cascadeList) {
                    QStringList fallbackList;
                    const int numCascades = CFArrayGetCount(cascadeList);
                    for (int i = 0; i < numCascades; ++i) {
                        CTFontDescriptorRef fontFallback = (CTFontDescriptorRef) CFArrayGetValueAtIndex(cascadeList, i);
                        QCFString fallbackFamilyName = (CFStringRef) CTFontDescriptorCopyAttribute(fontFallback, kCTFontFamilyNameAttribute);
                        fallbackList.append(QString::fromCFString(fallbackFamilyName));
                    }

                    addExtraFallbacks(&fallbackList);
                    extern QStringList qt_sort_families_by_writing_system(QChar::Script, const QStringList &);
                    fallbackList = qt_sort_families_by_writing_system(script, fallbackList);

                    return fallbackList;
                }
            }
        }
    }

    // We were not able to find a fallback for the specific family,
    // so we fall back to the stylehint.

    static const QString styleLookupKey = QString::fromLatin1(".QFontStyleHint_%1");

    static bool didPopulateStyleFallbacks = false;
    if (!didPopulateStyleFallbacks) {
#if defined(Q_OS_MACX)
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *languages = [defaults stringArrayForKey: @"AppleLanguages"];

        NSDictionary *fallbackDict = [NSDictionary dictionaryWithContentsOfFile: @"/System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreText.framework/Resources/DefaultFontFallbacks.plist"];

        for (NSString *style in [fallbackDict allKeys]) {
            NSArray *list = [fallbackDict valueForKey: style];
            QFont::StyleHint fallbackStyleHint = styleHintFromNSString(style);
            QStringList fallbackList;
            for (id item in list) {
                // sort the array based on system language preferences
                if ([item isKindOfClass: [NSArray class]]) {
                    NSArray *langs = [(NSArray *) item sortedArrayUsingFunction: languageMapSort
                                                                        context: languages];
                    for (NSArray *map in langs)
                        fallbackList.append(familyNameFromPostScriptName([map objectAtIndex: 1]));
                }
                else if ([item isKindOfClass: [NSString class]])
                    fallbackList.append(familyNameFromPostScriptName(item));
            }

            fallbackList.append(QLatin1String("Apple Color Emoji"));

            addExtraFallbacks(&fallbackList);
            fallbackLists[styleLookupKey.arg(fallbackStyleHint)] = fallbackList;
        }
#else
        QStringList staticFallbackList;
        staticFallbackList << QString::fromLatin1("Helvetica,Apple Color Emoji,Geeza Pro,Arial Hebrew,Thonburi,Kailasa"
            "Hiragino Kaku Gothic ProN,.Heiti J,Apple SD Gothic Neo,.Heiti K,Heiti SC,Heiti TC"
            "Bangla Sangam MN,Devanagari Sangam MN,Gujarati Sangam MN,Gurmukhi MN,Kannada Sangam MN"
            "Malayalam Sangam MN,Oriya Sangam MN,Sinhala Sangam MN,Tamil Sangam MN,Telugu Sangam MN"
            "Euphemia UCAS,.PhoneFallback").split(QLatin1String(","));

        for (int i = QFont::Helvetica; i <= QFont::Fantasy; ++i)
            fallbackLists[styleLookupKey.arg(i)] = staticFallbackList;
#endif

        didPopulateStyleFallbacks = true;
    }

    Q_ASSERT(!fallbackLists.isEmpty());
    return fallbackLists[styleLookupKey.arg(styleHint)];
}

QStringList QCoreTextFontDatabase::addApplicationFont(const QByteArray &fontData, const QString &fileName)
{
    QCFType<CFArrayRef> fonts;

    if (!fontData.isEmpty()) {
        QCFType<CFDataRef> fontDataReference = fontData.toRawCFData();
        if (QCFType<CTFontDescriptorRef> descriptor = CTFontManagerCreateFontDescriptorFromData(fontDataReference)) {
            // There's no way to get the data back out of a font descriptor created with
            // CTFontManagerCreateFontDescriptorFromData, so we attach the data manually.
            NSDictionary *attributes = @{ kQtFontDataAttribute : [NSValue valueWithPointer:new QByteArray(fontData)] };
            descriptor = CTFontDescriptorCreateCopyWithAttributes(descriptor, (CFDictionaryRef)attributes);
            CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
            CFArrayAppendValue(array, descriptor);
            fonts = array;
        }
    } else {
        QCFType<CFURLRef> fontURL = QUrl::fromLocalFile(fileName).toCFURL();
        fonts = CTFontManagerCreateFontDescriptorsFromURL(fontURL);
    }

    if (!fonts)
        return QStringList();

    QStringList families;
    const int numFonts = CFArrayGetCount(fonts);
    for (int i = 0; i < numFonts; ++i) {
        CTFontDescriptorRef fontDescriptor = CTFontDescriptorRef(CFArrayGetValueAtIndex(fonts, i));
        populateFromDescriptor(fontDescriptor);
        QCFType<CFStringRef> familyName = CFStringRef(CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontFamilyNameAttribute));
        families.append(QString::fromCFString(familyName));
    }

    // Note: We don't do font matching via CoreText for application fonts, so we don't
    // need to enable font matching for them via CTFontManagerEnableFontDescriptors.

    return families;
}

bool QCoreTextFontDatabase::isPrivateFontFamily(const QString &family) const
{
    if (family.startsWith(QLatin1Char('.')) || family == QLatin1String("LastResort"))
        return true;

    return QPlatformFontDatabase::isPrivateFontFamily(family);
}

static CTFontUIFontType fontTypeFromTheme(QPlatformTheme::Font f)
{
    switch (f) {
    case QPlatformTheme::SystemFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::MenuFont:
    case QPlatformTheme::MenuBarFont:
    case QPlatformTheme::MenuItemFont:
        return kCTFontUIFontMenuItem;

    case QPlatformTheme::MessageBoxFont:
        return kCTFontUIFontEmphasizedSystem;

    case QPlatformTheme::LabelFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::TipLabelFont:
        return kCTFontUIFontToolTip;

    case QPlatformTheme::StatusBarFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::TitleBarFont:
        return kCTFontUIFontWindowTitle;

    case QPlatformTheme::MdiSubWindowTitleFont:
    case QPlatformTheme::DockWidgetTitleFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::PushButtonFont:
        return kCTFontUIFontPushButton;

    case QPlatformTheme::CheckBoxFont:
    case QPlatformTheme::RadioButtonFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::ToolButtonFont:
        return kCTFontUIFontSmallToolbar;

    case QPlatformTheme::ItemViewFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::ListViewFont:
        return kCTFontUIFontViews;

    case QPlatformTheme::HeaderViewFont:
        return kCTFontUIFontSmallSystem;

    case QPlatformTheme::ListBoxFont:
        return kCTFontUIFontViews;

    case QPlatformTheme::ComboMenuItemFont:
        return kCTFontUIFontSystem;

    case QPlatformTheme::ComboLineEditFont:
        return kCTFontUIFontViews;

    case QPlatformTheme::SmallFont:
        return kCTFontUIFontSmallSystem;

    case QPlatformTheme::MiniFont:
        return kCTFontUIFontMiniSystem;

    case QPlatformTheme::FixedFont:
        return kCTFontUIFontUserFixedPitch;

    default:
        return kCTFontUIFontSystem;
    }
}

static CTFontDescriptorRef fontDescriptorFromTheme(QPlatformTheme::Font f)
{
#if defined(QT_PLATFORM_UIKIT)
    // Use Dynamic Type to resolve theme fonts if possible, to get
    // correct font sizes and style based on user configuration.
    NSString *textStyle = 0;
    switch (f) {
    case QPlatformTheme::TitleBarFont:
    case QPlatformTheme::HeaderViewFont:
        textStyle = UIFontTextStyleHeadline;
        break;
    case QPlatformTheme::MdiSubWindowTitleFont:
        textStyle = UIFontTextStyleSubheadline;
        break;
    case QPlatformTheme::TipLabelFont:
    case QPlatformTheme::SmallFont:
        textStyle = UIFontTextStyleFootnote;
        break;
    case QPlatformTheme::MiniFont:
        textStyle = UIFontTextStyleCaption2;
        break;
    case QPlatformTheme::FixedFont:
        // Fall back to regular code path, as iOS doesn't provide
        // an appropriate text style for this theme font.
        break;
    default:
        textStyle = UIFontTextStyleBody;
        break;
    }

    if (textStyle) {
        UIFontDescriptor *desc = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
        return static_cast<CTFontDescriptorRef>(CFBridgingRetain(desc));
    }
#endif // Q_OS_IOS, Q_OS_TVOS, Q_OS_WATCHOS

    // OSX default case and iOS fallback case
    CTFontUIFontType fontType = fontTypeFromTheme(f);
    QCFType<CTFontRef> ctFont = CTFontCreateUIFontForLanguage(fontType, 0.0, NULL);
    return CTFontCopyFontDescriptor(ctFont);
}

const QHash<QPlatformTheme::Font, QFont *> &QCoreTextFontDatabase::themeFonts() const
{
    if (m_themeFonts.isEmpty()) {
        for (long f = QPlatformTheme::SystemFont; f < QPlatformTheme::NFonts; f++) {
            QPlatformTheme::Font ft = static_cast<QPlatformTheme::Font>(f);
            m_themeFonts.insert(ft, themeFont(ft));
        }
    }

    return m_themeFonts;
}

QFont *QCoreTextFontDatabase::themeFont(QPlatformTheme::Font f) const
{
    CTFontDescriptorRef fontDesc = fontDescriptorFromTheme(f);
    FontDescription fd;
    getFontDescription(fontDesc, &fd);

    if (!m_systemFontDescriptors.contains(fontDesc))
        m_systemFontDescriptors.insert(fontDesc);
    else
        CFRelease(fontDesc);

    QFont *font = new QFont(fd.familyName, fd.pixelSize, fd.weight, fd.style == QFont::StyleItalic);
    return font;
}

QFont QCoreTextFontDatabase::defaultFont() const
{
    if (defaultFontName.isEmpty()) {
        QCFType<CTFontRef> font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 12.0, NULL);
        defaultFontName = (QString) QCFString(CTFontCopyFullName(font));
    }

    return QFont(defaultFontName);
}

bool QCoreTextFontDatabase::fontsAlwaysScalable() const
{
    return true;
}

QList<int> QCoreTextFontDatabase::standardSizes() const
{
    QList<int> ret;
    static const unsigned short standard[] =
        { 9, 10, 11, 12, 13, 14, 18, 24, 36, 48, 64, 72, 96, 144, 288, 0 };
    ret.reserve(int(sizeof(standard) / sizeof(standard[0])));
    const unsigned short *sizes = standard;
    while (*sizes) ret << *sizes++;
    return ret;
}

QT_END_NAMESPACE

