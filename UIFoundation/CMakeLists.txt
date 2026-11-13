project(UIFoundation)

include(darling_framework)

# The classes macOS ships in UIFoundation and that AppKit used to define itself: NSFont, NSFontDescriptor,
# NSParagraphStyle and its mutable subclass, NSShadow, NSTextAttachment, NSTextList, NSTextTab, the NSTextBlock family,
# NSTextStorage, NSTextContainer, NSLayoutManager, NSTypesetter and NSATSTypesetter, NSGlyphGenerator, NSGlyphInfo,
# NSDataAsset, NSAdaptiveImageGlyph, UINibEncoder, _NSAttributes, _NSAttributeRun and the minimal TextKit 2 classes.
#
# This is an object library: the UIFoundation framework itself is the target in src/private-frameworks/UIFoundation,
# which links these objects with the no-op classes that were already there. The objects must not import anything
# from AppKit (it links and re-exports UIFoundation); run check-boundary.sh on the linked images to check that.

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} \
	-include math.h \
	-include stdlib.h \
	-include CoreFoundation/CoreFoundation.h \
	-include Foundation/Foundation.h \
	-Wno-nonportable-include-path \
	-Wno-deprecated-objc-isa-usage \
	-mmacosx-version-min=10.10"
)

add_compile_definitions(
	OBJC_OLD_DISPATCH_PROTOTYPES=1
)

include_directories(
	${CMAKE_SOURCE_DIR}/src/external/icu/icuSources/i18n
	${CMAKE_SOURCE_DIR}/src/external/icu/icuSources/common

	${CMAKE_CURRENT_SOURCE_DIR}
	${CMAKE_CURRENT_SOURCE_DIR}/..
	${CMAKE_CURRENT_SOURCE_DIR}/../CoreText
	${CMAKE_CURRENT_SOURCE_DIR}/../AppKit
	${CMAKE_CURRENT_SOURCE_DIR}/../AppKit/NSTextView.subproj
	${CMAKE_CURRENT_SOURCE_DIR}/../QuartzCore/include
)

set(UIFoundation_sources
	NSATSTypesetter.m
	NSAdaptiveImageGlyph.m
	NSAttributeRun.m
	NSAttributedStringKeys.m
	NSBidiHelper.m
	NSDataAsset.m
	NSFont.m
	NSFontDescriptor.m
	NSGlyphGenerator.m
	NSGlyphInfo.m
	NSLayoutManager.m
	NSMutableParagraphStyle.m
	NSParagraphStyle.m
	NSRangeArray.m
	NSShadow.m
	NSTextAttachment.m
	NSTextContainer.m
	NSTextKit2.m
	NSTextList.m
	NSTextStorage.m
	NSTextStorage_concrete.m
	NSTextTab.m
	NSTypesetter.m
	NSTypesetter_concrete.m
	UIFAppKit.m
	UINibCoding.m
	NSTextTable/NSTextBlock.m
	NSTextTable/NSTextTable.m
	NSTextTable/NSTextTableBlock.m
)

set_source_files_properties(${UIFoundation_sources} LANGUAGE C)

add_darling_object_library(UIFoundation_text ${UIFoundation_sources})
set_target_properties(UIFoundation_text PROPERTIES POSITION_INDEPENDENT_CODE ON)
