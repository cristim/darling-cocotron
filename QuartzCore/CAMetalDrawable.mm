/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#define GL_GLEXT_PROTOTYPES 1

#import "CAMetalDrawableInternal.h"
#import "CAMetalLayerInternal.h"
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/MTLDeviceInternal.h>
#import <Metal/stubs.h>
#import "CGLReporting.h"

#if DARLING_METAL_ENABLED

#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <indium/indium.private.hpp>

namespace DynamicVK = Indium::DynamicVK;

// Defined here so the call sites below stay terse; the tracking itself is in
// CGLReporting.h so the layer and the drawable cannot drift apart.
static void reportGLErrors(void) {
	drainAndReportGLErrors("CAMetalDrawable");
}

//
// helper classes
//

// used to store a weak reference to an objc object within a C++ object (so it can be passed around in C++ code)
template<typename T>
class ObjcppWeakWrapper {
private:
	// needs to be mutable so we can use it in the copy constructor and the copy assignment operator.
	// plus, it's also modified externally, so it can never be truly const.
	mutable id _ref = nil;

public:
	ObjcppWeakWrapper() {};

	ObjcppWeakWrapper(T ref) {
		objc_storeWeak(&_ref, ref);
	};

	ObjcppWeakWrapper(const ObjcppWeakWrapper& other) {
		@autoreleasepool {
			objc_storeWeak(&_ref, objc_loadWeak(&other._ref));
		}
	};

	ObjcppWeakWrapper(ObjcppWeakWrapper&& other) {
		@autoreleasepool {
			objc_storeWeak(&_ref, objc_loadWeak(&other._ref));
			objc_storeWeak(&other._ref, nil);
		}
	};

	~ObjcppWeakWrapper() {
		objc_storeWeak(&_ref, nil);
	};

	ObjcppWeakWrapper& operator=(const ObjcppWeakWrapper& other) {
		@autoreleasepool {
			objc_storeWeak(&_ref, objc_loadWeak(&other._ref));
		}
		return *this;
	};

	ObjcppWeakWrapper& operator=(ObjcppWeakWrapper&& other) {
		@autoreleasepool {
			objc_storeWeak(&_ref, objc_loadWeak(&other._ref));
			objc_storeWeak(&other._ref, nil);
		}
		return *this;
	};

	operator T() const {
		return get();
	};

	T get() const {
		return objc_loadWeak(&_ref);
	};
};

//
// ideally, we would use a Vulkan surface + swapchain here to render directly to the screen.
// however, CALayers can also be rendered offscreen (e.g. with a CARenderer) and our current implementation of rendering
// in most places is to render to an OpenGL buffer (per window) and display that.
// plus, we don't have an easy way to get a surface here; we would need access to an X11 window/subwindow,
// which we don't have direct access to here (our delegate might). therefore, we follow suit
// with the existing CALayer implementation and just render to an image/texture.
//
// additionally, to avoid refactoring/reworking the existing CARenderer and CALayerContext code,
// we render to a Vulkan image and then hand its contents to an OpenGL texture. the handoff is a
// copy through host-visible memory rather than a shared buffer handle, and that is a considered
// choice rather than a shortcut. see -CAMetalDrawableTexture::synchronizeRender for the
// measurement behind it; the short version is that Vulkan and OpenGL here are not necessarily
// the same device (indium takes the first Vulkan physical device, while CGL's context comes from
// whatever EGL display a window backend registered), no GL_EXT_semaphore exists to synchronize
// a shared handle, and the GL_EXT_memory_object_fd import path is absent on the accelerated
// context. so there is nothing to share; there is only a copy.

//
// texture
//

static size_t findSharedMemory(const VkMemoryRequirements& reqs, std::shared_ptr<Indium::PrivateDevice> device, bool framebufferOnly) {
	size_t targetIndex = SIZE_MAX;

	for (size_t i = 0; i < device->memoryProperties().memoryTypeCount; ++i) {
		const auto& type = device->memoryProperties().memoryTypes[i];

		if ((reqs.memoryTypeBits & (1 << i)) == 0) {
			continue;
		}

		if (!framebufferOnly && (type.propertyFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) == 0) {
			continue;
		}

		if (!framebufferOnly && (type.propertyFlags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) == 0) {
			continue;
		}

		// okay, this is good enough
		targetIndex = i;
		break;
	}

	return targetIndex;
};

CAMetalDrawableTexture::CAMetalDrawableTexture(CGSize size, Indium::PixelFormat pixelFormat, bool framebufferOnly, std::shared_ptr<Indium::PrivateDevice> privateDevice):
	Indium::PrivateTexture(privateDevice),
	_size(size),
	_pixelFormat(pixelFormat),
	_framebufferOnly(framebufferOnly)
{
	//
	// create the images
	//

	// create the public Vulkan image
	VkImageCreateInfo imgInfo {};

	imgInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
	imgInfo.imageType = VK_IMAGE_TYPE_2D;
	imgInfo.format = Indium::pixelFormatToVkFormat(_pixelFormat);
	imgInfo.extent.width = _size.width;
	imgInfo.extent.height = _size.height;
	imgInfo.extent.depth = 1;
	imgInfo.mipLevels = 1;
	imgInfo.arrayLayers = 1;
	imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
	imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
	imgInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
	imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
	imgInfo.queueFamilyIndexCount = 0;
	imgInfo.pQueueFamilyIndices = nullptr;
	imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

	if (DynamicVK::vkCreateImage(_device->device(), &imgInfo, nullptr, &_image) != VK_SUCCESS) {
		// TODO
		abort();
	}

	// now create the internal image, which precommit blits into
	imgInfo.format = VK_FORMAT_R8G8B8A8_UNORM;

	// LINEAR rather than OPTIMAL tiling, because the whole point of this image
	// is that its contents get read on the host (see -synchronizeRender); an
	// optimal-tiled image has no host-readable layout.
	imgInfo.tiling = VK_IMAGE_TILING_LINEAR;

	if (DynamicVK::vkCreateImage(_device->device(), &imgInfo, nullptr, &_internalImage) != VK_SUCCESS) {
		// TODO
		abort();
	}

	//
	// allocate some memory for the images
	//

	VkMemoryRequirements reqs {};

	// first, the public image

	DynamicVK::vkGetImageMemoryRequirements(_device->device(), _image, &reqs);

	size_t targetIndex = findSharedMemory(reqs, _device, _framebufferOnly);

	if (targetIndex == SIZE_MAX) {
		throw std::runtime_error("No suitable memory region found for image");
	}

	VkMemoryAllocateInfo allocInfo {};

	allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
	allocInfo.allocationSize = reqs.size;
	allocInfo.memoryTypeIndex = targetIndex;

	if (DynamicVK::vkAllocateMemory(_device->device(), &allocInfo, nullptr, &_memory) != VK_SUCCESS) {
		// TODO
		abort();
	}

	DynamicVK::vkBindImageMemory(_device->device(), _image, _memory, 0);

	// now, the internal image

	DynamicVK::vkGetImageMemoryRequirements(_device->device(), _internalImage, &reqs);

	// The presentation image is read on the CPU even for framebuffer-only
	// public textures, so it always needs host-visible, coherent memory.
	targetIndex = findSharedMemory(reqs, _device, false);

	if (targetIndex == SIZE_MAX) {
		throw std::runtime_error("No suitable memory region found for internal image");
	}

	VkMemoryDedicatedAllocateInfo dedicatedInfo {};

	allocInfo.allocationSize = reqs.size;
	allocInfo.memoryTypeIndex = targetIndex;

	// A dedicated allocation, and no export: this memory is read back on the
	// host and uploaded to GL, not shared with it.
	dedicatedInfo.sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO;
	dedicatedInfo.image = _internalImage;

	allocInfo.pNext = &dedicatedInfo;

	if (DynamicVK::vkAllocateMemory(_device->device(), &allocInfo, nullptr, &_internalMemory) != VK_SUCCESS) {
		// TODO
		abort();
	}

	DynamicVK::vkBindImageMemory(_device->device(), _internalImage, _internalMemory, 0);

	//
	// transition the images into the general layout
	//

	VkCommandBufferAllocateInfo cmdBufAllocInfo {};
	cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	cmdBufAllocInfo.commandPool = _device->oneshotCommandPool();
	cmdBufAllocInfo.commandBufferCount = 1;

	VkCommandBuffer cmdBuf;
	if (DynamicVK::vkAllocateCommandBuffers(_device->device(), &cmdBufAllocInfo, &cmdBuf) != VK_SUCCESS) {
		// TODO
		abort();
	}

	VkCommandBufferBeginInfo cmdBufBeginInfo {};
	cmdBufBeginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
	cmdBufBeginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

	DynamicVK::vkBeginCommandBuffer(cmdBuf, &cmdBufBeginInfo);

	VkImageMemoryBarrier barriers[2];

	barriers[0] = {};
	barriers[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
	barriers[0].srcAccessMask = VK_ACCESS_NONE;
	barriers[0].dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
	barriers[0].oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
	barriers[0].newLayout = VK_IMAGE_LAYOUT_GENERAL;
	barriers[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barriers[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barriers[0].image = _image;
	barriers[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
	barriers[0].subresourceRange.baseMipLevel = 0;
	barriers[0].subresourceRange.levelCount = 1;
	barriers[0].subresourceRange.baseArrayLayer = 0;
	barriers[0].subresourceRange.layerCount = 1;

	barriers[1] = barriers[0];
	barriers[1].image = _internalImage;

	DynamicVK::vkCmdPipelineBarrier(cmdBuf, VK_PIPELINE_STAGE_NONE, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, nullptr, 0, nullptr, sizeof(barriers) / sizeof(*barriers), barriers);

	DynamicVK::vkEndCommandBuffer(cmdBuf);

	VkFenceCreateInfo fenceCreateInfo {};
	fenceCreateInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

	VkFence theFence = VK_NULL_HANDLE;

	if (DynamicVK::vkCreateFence(_device->device(), &fenceCreateInfo, nullptr, &theFence) != VK_SUCCESS) {
		// TODO
		abort();
	}

	VkSubmitInfo submitInfo {};
	submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
	submitInfo.commandBufferCount = 1;
	submitInfo.pCommandBuffers = &cmdBuf;

	DynamicVK::vkQueueSubmit(_device->graphicsQueue(), 1, &submitInfo, theFence);
	if (DynamicVK::vkWaitForFences(_device->device(), 1, &theFence, VK_TRUE, /* 1s */ 1ull * 1000 * 1000 * 1000) != VK_SUCCESS) {
		// TODO
		abort();
	}

	DynamicVK::vkDestroyFence(_device->device(), theFence, nullptr);

	DynamicVK::vkFreeCommandBuffers(_device->device(), _device->oneshotCommandPool(), 1, &cmdBuf);

	//
	// create an image view for the public image
	//

	VkImageViewCreateInfo imgViewInfo {};
	imgViewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
	imgViewInfo.image = _image;
	imgViewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
	imgViewInfo.format = Indium::pixelFormatToVkFormat(_pixelFormat);
	imgViewInfo.components.r = VK_COMPONENT_SWIZZLE_R;
	imgViewInfo.components.g = VK_COMPONENT_SWIZZLE_G;
	imgViewInfo.components.b = VK_COMPONENT_SWIZZLE_B;
	imgViewInfo.components.a = VK_COMPONENT_SWIZZLE_A;
	imgViewInfo.subresourceRange = barriers[0].subresourceRange;

	if (DynamicVK::vkCreateImageView(_device->device(), &imgViewInfo, nullptr, &_imageView) != VK_SUCCESS) {
		// TODO
		abort();
	}

};

CAMetalDrawableTexture::~CAMetalDrawableTexture() {
	DynamicVK::vkDestroyImageView(_device->device(), _imageView, nullptr);
	DynamicVK::vkDestroyImage(_device->device(), _image, nullptr);
	DynamicVK::vkFreeMemory(_device->device(), _memory, nullptr);
	DynamicVK::vkDestroyImage(_device->device(), _internalImage, nullptr);
	DynamicVK::vkFreeMemory(_device->device(), _internalMemory, nullptr);
};

// The handoff: read the rendered image back out of host-visible memory and
// upload it into the GL texture the compositor samples.
//
// Why a copy and not a shared handle. Three things have to hold for a
// zero-copy import, and none of them do on this platform:
//
//   - Both stacks must be on the same physical device. They are not.
//     indium takes the first Vulkan physical device, and on an Asahi M1 that
//     is the GPU ("Apple M1"); cocotron's CGL builds its context from the EGL
//     display a window backend registered, and the X11/Xvfb path lands on
//     llvmpipe, a CPU rasterizer. A dma-buf from the GPU is not memory llvmpipe
//     can sample.
//   - GL must have a dma-buf import path. On the accelerated context
//     GL_EXT_memory_object and GL_EXT_memory_object_fd are both absent, so
//     glCreateMemoryObjectsEXT fails with GL_INVALID_OPERATION. The X11 path does
//     have them, but it is the mismatched one.
//   - Something must synchronize the two. There is no GL_EXT_semaphore and no
//     GL_ARB_semaphore on either context, so the old glImportSemaphoreFdEXT and
//     glWaitSemaphoreEXT pair could not have worked even with a shared buffer.
//
// The old code tried this anyway, passing a Vulkan opaque fd to
// glImportMemoryFdEXT. In GL that handle type means a dma-buf, and a Vulkan
// opaque fd is not one, so the import silently produced a memory object with no
// backing and glTextureStorageMem2DEXT then failed; with the errors now
// reported that shows up as 3x GL_INVALID_OPERATION and an incomplete FBO, and
// the layer stayed blank. A copy is slower, and it is the only thing that is
// correct here.
//
// So: wait for the signal that says precommit's blit into _internalImage has
// landed, map that image, and hand the rows to GL.
void CAMetalDrawableTexture::synchronizeRender(GLuint texture, std::shared_ptr<Indium::BinarySemaphore> sema) {
	if (sema) {
		// A host-side wait, unlike the GL semaphore this replaces. The whole
		// point of reading the image on the host is that we are on the CPU for
		// this step anyway, so a GPU-side wait would buy nothing.
		//
		// The presentation semaphore is a binary one, and vkWaitSemaphores only
		// accepts timeline semaphores, so the wait is expressed as an empty
		// submission that waits on it and signals a fence. The queue is in
		// order, so the fence cannot signal before the submit that carries
		// precommit's blit -- and therefore the blit -- has completed.
		VkFenceCreateInfo fenceInfo {};
		fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

		VkFence fence = VK_NULL_HANDLE;
		if (DynamicVK::vkCreateFence(_device->device(), &fenceInfo, nullptr, &fence) != VK_SUCCESS) {
			NSLog(@"CAMetalDrawable: could not create a fence to wait on the drawable");
			return;
		}

		VkSemaphore waitSemaphores[] = {sema->semaphore};

		VkPipelineStageFlags waitStage = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT;

		VkSubmitInfo submitInfo {};
		submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
		submitInfo.waitSemaphoreCount = 1;
		submitInfo.pWaitSemaphores = waitSemaphores;
		submitInfo.pWaitDstStageMask = &waitStage;

		VkResult submitted = DynamicVK::vkQueueSubmit(_device->graphicsQueue(), 1, &submitInfo, fence);
		VkResult waited = VK_SUCCESS;

		if (submitted == VK_SUCCESS) {
			waited = DynamicVK::vkWaitForFences(_device->device(), 1, &fence, VK_TRUE, UINT64_MAX);
		}

		DynamicVK::vkDestroyFence(_device->device(), fence, nullptr);

		if (submitted != VK_SUCCESS || waited != VK_SUCCESS) {
			// Returning here leaves the texture holding the previous frame,
			// which is the failure this replaced, so say so rather than
			// uploading stale contents silently.
			NSLog(@"CAMetalDrawable: waiting for the drawable's render failed (submit %d, wait %d)",
			       submitted, waited);
			return;
		}
	}

	// The image is LINEAR tiled, so its subresource layout is the host layout
	// and the row pitch has to be honoured rather than assumed. It is usually
	// width*4, but not necessarily, and assuming so would shear the image.
	VkImageSubresource subresource {};
	subresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
	subresource.mipLevel = 0;
	subresource.arrayLayer = 0;

	VkSubresourceLayout layout {};
	static PFN_vkGetImageSubresourceLayout pfnGetLayout = nullptr;
	if (!pfnGetLayout) {
		pfnGetLayout = (PFN_vkGetImageSubresourceLayout)DynamicVK::vkGetInstanceProcAddr(
			Indium::globalInstance, "vkGetImageSubresourceLayout");
	}
	if (pfnGetLayout) {
		pfnGetLayout(_device->device(), _internalImage, &subresource, &layout);
	}

	if (layout.rowPitch == 0 || layout.size == 0) {
		NSLog(@"CAMetalDrawable: the drawable's internal image has no host layout");
		return;
	}

	void* mapped = nullptr;
	if (DynamicVK::vkMapMemory(_device->device(), _internalMemory, 0, VK_WHOLE_SIZE, 0, &mapped) != VK_SUCCESS) {
		NSLog(@"CAMetalDrawable: could not map the drawable's internal image");
		return;
	}

	// The memory is HOST_COHERENT (findSharedMemory only picks such a type), so
	// the host sees the blit without an explicit invalidate.

	const size_t rowPitch = layout.rowPitch;
	const size_t height = _size.height;
	const size_t width = _size.width;
	const unsigned char* src = reinterpret_cast<const unsigned char*>(mapped) + layout.offset;


	glPixelStorei(GL_UNPACK_ALIGNMENT, static_cast<GLint>(layout.rowPitch % 4 == 0 ? 4 : 1));
	glPixelStorei(GL_UNPACK_ROW_LENGTH, static_cast<GLint>(rowPitch / 4));

	glTextureSubImage2D(texture, 0, 0, 0, static_cast<GLsizei>(width), static_cast<GLsizei>(height),
	                    GL_RGBA, GL_UNSIGNED_BYTE, src);

	reportGLErrors();

	DynamicVK::vkUnmapMemory(_device->device(), _internalMemory);
};

VkImageView CAMetalDrawableTexture::imageView() {
	return _imageView;
};

VkImage CAMetalDrawableTexture::image() {
	return _image;
};

VkImageLayout CAMetalDrawableTexture::imageLayout() {
	return VK_IMAGE_LAYOUT_GENERAL;
};

Indium::TextureType CAMetalDrawableTexture::textureType() const {
	return Indium::TextureType::e2D;
};

Indium::PixelFormat CAMetalDrawableTexture::pixelFormat() const {
	return _pixelFormat;
};

size_t CAMetalDrawableTexture::width() const {
	return _size.width;
};

size_t CAMetalDrawableTexture::height() const {
	return _size.height;
};

size_t CAMetalDrawableTexture::depth() const {
	return 1;
};

size_t CAMetalDrawableTexture::mipmapLevelCount() const {
	return 1;
};

size_t CAMetalDrawableTexture::arrayLength() const {
	return 1;
};

size_t CAMetalDrawableTexture::sampleCount() const {
	return 1;
};

bool CAMetalDrawableTexture::framebufferOnly() const {
	// TODO: determine this according to the layer
	return false;
};

bool CAMetalDrawableTexture::allowGPUOptimizedContents() const {
	return true;
};

bool CAMetalDrawableTexture::shareable() const {
	return false;
};

Indium::TextureSwizzleChannels CAMetalDrawableTexture::swizzle() const {
	return {};
};

void CAMetalDrawableTexture::replaceRegion(Indium::Region region, size_t mipmapLevel, const void* bytes, size_t bytesPerRow) {
	// TODO
	abort();
};

void CAMetalDrawableTexture::replaceRegion(Indium::Region region, size_t mipmapLevel, size_t slice, const void* bytes, size_t bytesPerRow, size_t bytesPerImage) {
	// TODO
	abort();
};

// Reading a drawable's texture back is not a thing an app can ask Metal for: the
// drawable's texture is the layer's colour attachment, and -[MTLTexture getBytes:]
// on it would hand back whatever the compositor has not consumed yet. Indium
// declares these pure virtual, so a drawable texture has to answer; refuse
// explicitly rather than return whatever happens to be in the image. Indium's own
// failures travel as std::runtime_error, which -[MTLTexture getBytes:] turns into
// an NSException, so throwing here surfaces as a normal Cocoa error to the caller.
void CAMetalDrawableTexture::getBytes(Indium::Region region, size_t mipmapLevel, void* bytes, size_t bytesPerRow) {
	throw std::runtime_error("Cannot read back a CAMetalDrawable's texture; "
	                         "read back a texture you created instead");
}

void CAMetalDrawableTexture::getBytes(Indium::Region region, size_t mipmapLevel, size_t slice, void* bytes, size_t bytesPerRow, size_t bytesPerImage) {
	throw std::runtime_error("Cannot read back a CAMetalDrawable's texture; "
	                         "read back a texture you created instead");
}

void CAMetalDrawableTexture::precommit(std::shared_ptr<Indium::PrivateCommandBuffer> cmdbuf) {
	// The blit below lands in _internalImage, which -synchronizeRender then reads
	// on the host, so both images are transitioned and the blit is fenced by the
	// submit this command buffer goes out in. The presentation semaphore that
	// -synchronizeRender waits on is signalled by that same submit, which is what
	// makes the host read of the internal image ordered after the blit.

	VkImageMemoryBarrier barriers[2];

	barriers[0] = {};
	barriers[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
	barriers[0].srcAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
	barriers[0].dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
	barriers[0].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
	barriers[0].newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
	barriers[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barriers[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
	barriers[0].image = _image;
	barriers[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
	barriers[0].subresourceRange.baseMipLevel = 0;
	barriers[0].subresourceRange.levelCount = 1;
	barriers[0].subresourceRange.baseArrayLayer = 0;
	barriers[0].subresourceRange.layerCount = 1;

	barriers[1] = barriers[0];
	barriers[1].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
	barriers[1].newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
	barriers[1].image = _internalImage;

	DynamicVK::vkCmdPipelineBarrier(cmdbuf->commandBuffer(), VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0, nullptr, sizeof(barriers) / sizeof(*barriers), barriers);

	VkImageBlit region {};

	region.srcOffsets[0] = { 0, 0, 0 };
	region.srcOffsets[1] = { static_cast<int32_t>(width()), static_cast<int32_t>(height()), 1 };
	region.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
	region.srcSubresource.mipLevel = 0;
	region.srcSubresource.baseArrayLayer = 0;
	region.srcSubresource.layerCount = 1;

	region.dstOffsets[0] = region.srcOffsets[0];
	region.dstOffsets[1] = region.srcOffsets[1];
	region.dstSubresource = region.srcSubresource;

	DynamicVK::vkCmdBlitImage(cmdbuf->commandBuffer(), _image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, _internalImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region, VK_FILTER_LINEAR);

	barriers[0].srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
	barriers[0].dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
	barriers[0].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
	barriers[0].newLayout = VK_IMAGE_LAYOUT_GENERAL;

	barriers[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
	barriers[1].dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
	barriers[1].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
	barriers[1].newLayout = VK_IMAGE_LAYOUT_GENERAL;

	DynamicVK::vkCmdPipelineBarrier(cmdbuf->commandBuffer(), VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0, nullptr, sizeof(barriers) / sizeof(*barriers), barriers);
};

bool CAMetalDrawableTexture::needsExportablePresentationSemaphore() const {
	// The presentation semaphore is waited on by the host in
	// -synchronizeRender, never handed to another API, so it does not need to be
	// exportable. It used to say yes because the semaphore was exported into a GL
	// semaphore, which is gone along with the shared-memory handoff.
	return false;
};

//
// drawable
//

CAMetalDrawableActual::CAMetalDrawableActual(CAMetalLayerInternal* layer, CGSize size, NSUInteger drawableID, Indium::PixelFormat pixelFormat, std::shared_ptr<Indium::Device> device, CGLContextObj glContext):
	_drawableID(drawableID),
	_glContext(CGLRetainContext(glContext))
{
	_texture = std::make_shared<CAMetalDrawableTexture>(size, pixelFormat, layer.framebufferOnly, std::dynamic_pointer_cast<Indium::PrivateDevice>(device));
	objc_storeWeak(&_layer, layer);
};

CAMetalDrawableActual::~CAMetalDrawableActual() {
	reset();
	objc_storeWeak(&_layer, nil);
	CGLReleaseContext(_glContext);
};

void CAMetalDrawableActual::present() {
	if (_queued) {
		if (_wantsToPresentCallback) {
			_wantsToPresentCallback();
			_wantsToPresentCallback = nullptr;
		}
		if (_didPresentCallback) {
			_didPresentCallback();
			_didPresentCallback = nullptr;
		}
		return;
	}

	_queued = true;

	if (_wantsToPresentCallback) {
		_wantsToPresentCallback();
		_wantsToPresentCallback = nullptr;
	}

	@autoreleasepool {
		CAMetalLayerInternal* layer = objc_loadWeak(&_layer);

		if (!layer) {
			// if we've been disowned, drop all presentation requests
			didDrop();
			return;
		}

		[layer queuePresent: _drawableID];

		// The semaphore is kept for -synchronizeRender to wait on, rather than
		// exported into a GL semaphore. There is no GL_EXT_semaphore on either
		// context, so the export could not have been imported; and since the
		// handoff reads the image on the host anyway, the wait belongs on the
		// host too.
		_semaphore = _texture->synchronizePresentation();
	}
}

std::shared_ptr<CAMetalDrawableTexture> CAMetalDrawableActual::texture() {
	return _texture;
};

NSUInteger CAMetalDrawableActual::drawableID() const {
	return _drawableID;
};

CFTimeInterval CAMetalDrawableActual::presentedTime() const {
	return _presentedTime;
};

void CAMetalDrawableActual::setWantsToPresentCallback(std::function<void()> wantsToPresentCallback) {
	_wantsToPresentCallback = wantsToPresentCallback;
};

void CAMetalDrawableActual::setDidPresentCallback(std::function<void()> didPresentCallback) {
	_didPresentCallback = didPresentCallback;
};

void CAMetalDrawableActual::disown() {
	objc_storeWeak(&_layer, nil);
};

void CAMetalDrawableActual::didPresent() {
	_presentedTime = CACurrentMediaTime();

	if (_didPresentCallback) {
		_didPresentCallback();
		_didPresentCallback = nullptr;
	}
};

void CAMetalDrawableActual::didDrop() {
	_presentedTime = 0;

	if (_didPresentCallback) {
		_didPresentCallback();
		_didPresentCallback = nullptr;
	}
};

void CAMetalDrawableActual::release() {
	@autoreleasepool {
		CAMetalLayerInternal* layer = objc_loadWeak(&_layer);
		[layer releaseDrawable: _drawableID];
	}
};

void CAMetalDrawableActual::reset() {
	_semaphore = nullptr;
	_wantsToPresentCallback = nullptr;
	_didPresentCallback = nullptr;
	_presentedTime = 0;
	_queued = false;
};

void CAMetalDrawableActual::synchronizeRender(GLuint texture) {
	// Called from the layer context's render thread with that context's CGL
	// context current, which is what the upload needs.
	_texture->synchronizeRender(texture, _semaphore);
};

static void glDebugCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* context) {
	fprintf(stderr, "GL CALLBACK: %s type = 0x%x, severity = 0x%x, message = %s\n", (type == GL_DEBUG_TYPE_ERROR ? "** GL ERROR **" : ""), type, severity, message);
};

// MTLTextureInternal is a private class of Darling's Metal. Naming it in code makes
// QuartzCore import its class symbol, and a Metal served from elsewhere (the macOS
// dyld shared cache) does not export it, so QuartzCore would fail to bind at load.
// Look it up when a drawable is made instead.
static Class darlingTextureClass(void) {
	static Class textureClass = Nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		textureClass = objc_getClass("MTLTextureInternal");
	});
	return textureClass;
}

@implementation CAMetalDrawableInternal

@synthesize drawableID = _drawableID;
@synthesize presentedTime = _presentedTime;
@synthesize texture = _texture;
@synthesize layer = _layer;

#if 0
+ (void)initialize
{
	glEnable(GL_DEBUG_OUTPUT);
	glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
	glDebugMessageCallback(glDebugCallback, NULL);
}
#endif

- (instancetype)initWithLayer: (CAMetalLayer*)layer
                     drawable: (std::shared_ptr<CAMetalDrawableActual>)drawable
{
	self = [super init];
	if (self != nil) {
		_layer = [layer retain];
		_drawableID = drawable->drawableID();
		_presentedHandlers = [NSMutableArray new];
		_drawable = drawable;

		Class textureClass = darlingTextureClass();
		if (textureClass == Nil || ![textureClass instancesRespondToSelector: @selector(initWithTexture:device:resourceOptions:)]) {
			// QuartzCore is paired with a Metal that is not Darling's. -dealloc recycles the drawable.
			[self release];
			[NSException raise: NSInternalInconsistencyException format: @"CAMetalDrawable needs Darling's Metal, which provides MTLTextureInternal"];
		}

		_texture = [(MTLTextureInternal*)[textureClass alloc] initWithTexture: drawable->texture() device: layer.device resourceOptions: MTLResourceStorageModeShared];

		_drawable->reset();

		_drawable->setWantsToPresentCallback([weakSelf = ObjcppWeakWrapper(self)]() {
			@autoreleasepool {
				CAMetalDrawableInternal* me = weakSelf.get();

				if (!me) {
					return;
				}

				// ensure we stick around to see final presentation so we can notify _presentedHandlers
				// even if the user drops all their references to the drawable object
				//
				// once the wantsToPresentCallback is invoked (the one we're in right now),
				// it's guaranteed that the didPresentCallback will invoked (either for presentation
				// or for dropping), so we can be sure we're not leaking ourselves here.
				[me retain];
				me->_drawable->setDidPresentCallback([=]() {
					@autoreleasepool {
						// autorelease ourselves
						[me autorelease];

						me->_presentedTime = me->_drawable->presentedTime();

						// TODO: synchronize/lock this
						for (MTLDrawablePresentedHandler handler in me->_presentedHandlers) {
							handler(me);
						}

						// release the C++ drawable instance (and allow it to be recycled)
						me->_drawable->release();
						me->_drawable = nullptr;

						// XXX: it's not clear whether the texture is still accessible after presentation,
						//      but it *seems* that it would no longer be accessible. according to the documentation,
						//      you can safely retain a drawable to query certain properties such as drawableID and presentedTime,
						//      but no mention of texture is made.
						// TODO: verify this
						[me->_texture release];
						me->_texture = nil;
					}
				});
			}
		});
	}
	return self;
}

- (void)dealloc
{
	// explicitly release the drawable, in case it hasn't been released already.
	// this occurs when the drawable is requested (via nextDrawable from CAMetalLayer) but never presented.
	if (_drawable) {
		_drawable->release();
	}

	[_texture release];
	[_layer release];
	[_presentedHandlers release];

	[super dealloc];
}

- (void)present
{
	_drawable->present();
}

// Metal offers three ways to ask for a present, differing only in when the system
// is asked to show the frame. This implementation has one clock: -queuePresent: hands
// the drawable to the render timer, which composites it on the next display tick.
// There is no timed queue, so a duration or a target time cannot be scheduled. Rather
// than refuse a call the API treats as an ordinary present, present on that tick and
// say once that the hint was dropped -- an app that paces itself should know its hint
// is not being honoured instead of silently getting frames early.
static void warnUnschedulablePresent(NSString* what, CFTimeInterval value) {
	static int warned;
	if (!__sync_lock_test_and_set(&warned, 1)) {
		NSLog(@"CAMetalDrawable: %@ %.6f cannot be scheduled; presents go out on the next display tick",
		      what, value);
	}
}

- (void)presentAfterMinimumDuration: (CFTimeInterval)duration
{
	if (duration > 0) {
		warnUnschedulablePresent(@"presentAfterMinimumDuration:", duration);
	}
	[self present];
}

- (void)presentAtTime: (CFTimeInterval)presentationTime
{
	// A time already in the past means "as soon as possible", which is exactly what
	// the next tick delivers, so only a future time is a dropped hint.
	if (presentationTime > CACurrentMediaTime()) {
		warnUnschedulablePresent(@"presentAtTime:", presentationTime);
	}
	[self present];
}

- (void)addPresentedHandler: (MTLDrawablePresentedHandler)block
{
	[_presentedHandlers addObject: [[block copy] autorelease]];
}

- (std::shared_ptr<Indium::Drawable>)drawable
{
	return _drawable;
}

@end

#else

@implementation CAMetalDrawableInternal

@dynamic texture;
@dynamic layer;
@dynamic drawableID;
@dynamic presentedTime;

MTL_UNSUPPORTED_CLASS

@end

#endif
