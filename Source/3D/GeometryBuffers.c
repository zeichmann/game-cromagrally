// GPU-resident geometry for the OpenGL compatibility renderer.

#include "game.h"
#include <SDL3/SDL_opengl_glext.h>

static PFNGLGENBUFFERSPROC gGenBuffers;
static PFNGLBINDBUFFERPROC gBindBuffer;
static PFNGLBUFFERDATAPROC gBufferData;
static PFNGLDELETEBUFFERSPROC gDeleteBuffers;
static Boolean gGeometryBuffersAvailable;

void MO_InitGeometryBuffers(void)
{
	gGenBuffers = (PFNGLGENBUFFERSPROC) SDL_GL_GetProcAddress("glGenBuffers");
	gBindBuffer = (PFNGLBINDBUFFERPROC) SDL_GL_GetProcAddress("glBindBuffer");
	gBufferData = (PFNGLBUFFERDATAPROC) SDL_GL_GetProcAddress("glBufferData");
	gDeleteBuffers = (PFNGLDELETEBUFFERSPROC) SDL_GL_GetProcAddress("glDeleteBuffers");
	gGeometryBuffersAvailable = gGenBuffers && gBindBuffer && gBufferData && gDeleteBuffers
		&& !SDL_getenv("CMR_DISABLE_GPU_BUFFERS");
}

// CPU arrays remain available for collisions, bounds, and legacy dynamic draws.
void MO_InvalidateGeometryBuffers(MOVertexArrayData *data)
{
	if (data->gpuBuffers[0])
	{
		gDeleteBuffers(kNumGeometryBuffers, data->gpuBuffers);
		SDL_memset(data->gpuBuffers, 0, sizeof(data->gpuBuffers));
	}
}

void MO_UploadGeometryBuffers(MOVertexArrayData *data)
{
	if (!gGeometryBuffersAvailable || !data->gpuResident || data->gpuBuffers[0]
		|| data->numPoints <= 0 || data->numTriangles <= 0)
		return;

	const void* arrays[kNumGeometryBuffers] = {
		data->points, data->normals, data->uvs, data->colorsByte, data->colorsFloat, data->triangles,
	};
	const GLsizeiptr sizes[kNumGeometryBuffers] = {
		(GLsizeiptr) data->numPoints * sizeof(*data->points),
		(GLsizeiptr) data->numPoints * sizeof(*data->normals),
		(GLsizeiptr) data->numPoints * sizeof(*data->uvs),
		(GLsizeiptr) data->numPoints * sizeof(*data->colorsByte),
		(GLsizeiptr) data->numPoints * sizeof(*data->colorsFloat),
		(GLsizeiptr) data->numTriangles * sizeof(*data->triangles),
	};

	gGenBuffers(kNumGeometryBuffers, data->gpuBuffers);
	for (int i = 0; i < kNumGeometryBuffers; i++)
	{
		if (!arrays[i])
			continue;
		GLenum target = i == kBufferIndices ? GL_ELEMENT_ARRAY_BUFFER : GL_ARRAY_BUFFER;
		gBindBuffer(target, data->gpuBuffers[i]);
		gBufferData(target, sizes[i], arrays[i], GL_STATIC_DRAW);
	}
	gBindBuffer(GL_ARRAY_BUFFER, 0);
	gBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	if (glGetError() != GL_NO_ERROR)
	{
		// Allocation failure must not break rendering on a memory-constrained GPU.
		MO_InvalidateGeometryBuffers(data);
		data->gpuResident = false;
		while (glGetError() != GL_NO_ERROR) {}
	}
}

const void* MO_GeometryArray(const MOVertexArrayData *data, int array, const void* cpuArray)
{
	if (!gGeometryBuffersAvailable)
		return cpuArray;
	Boolean buffered = data->gpuBuffers[0] != 0;
	gBindBuffer(array == kBufferIndices ? GL_ELEMENT_ARRAY_BUFFER : GL_ARRAY_BUFFER,
		buffered ? data->gpuBuffers[array] : 0);
	return buffered ? NULL : cpuArray;
}

void MO_UnbindGeometryBuffers(void)
{
	if (gGeometryBuffersAvailable)
	{
		gBindBuffer(GL_ARRAY_BUFFER, 0);
		gBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	}
}
