project(CollectionViewCore)

include(darling_framework)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} \
	-include math.h \
	-include stdlib.h \
	-include CoreFoundation/CoreFoundation.h \
	-include Foundation/Foundation.h \
	-Wno-nonportable-include-path \
	-Wno-deprecated-objc-isa-usage \
	-mmacosx-version-min=10.10"
)

include_directories(
	${CMAKE_CURRENT_SOURCE_DIR}
)

# Apple's private framework that owns the NSCollectionLayout* classes. AppKit re-exports it, so an
# application that imports one of them from AppKit binds here. Its public declarations stay in
# AppKit's headers (NSCollectionViewCompositionalLayout.h), which is all this code needs from AppKit.
set(CollectionViewCore_sources
	NSCollectionLayout.m
)

set_source_files_properties(${CollectionViewCore_sources} LANGUAGE C)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

add_framework(CollectionViewCore
	FAT
	CURRENT_VERSION
	PRIVATE
	SOURCES
		${CollectionViewCore_sources}
	VERSION ${FRAMEWORK_VERSION}
	DEPENDENCIES
		objc
		system
		CoreFoundation
		Foundation
)
