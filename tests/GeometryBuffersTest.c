// Exercise the real buffer backend with a recording GL driver (no window needed).
#include "game.h"
#include <SDL3/SDL_opengl_glext.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "Failed at line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)

static int uploads, deletions, generations;
static GLuint arrayBinding, indexBinding;
static GLuint nextName = 1;
static GLenum pendingError;
static size_t uploadedBytes;

static GLenum TestGetError(void)
{
	GLenum error = pendingError;
	pendingError = GL_NO_ERROR;
	return error;
}

#define glGetError TestGetError
#include "../Source/3D/GeometryBuffers.c"
#undef glGetError

static void APIENTRY TestGenBuffers(GLsizei count, GLuint* names)
{
	generations++;
	for (int i = 0; i < count; i++) names[i] = nextName++;
}

static void APIENTRY TestBindBuffer(GLenum target, GLuint name)
{
	if (target == GL_ARRAY_BUFFER) arrayBinding = name;
	else { CHECK(target == GL_ELEMENT_ARRAY_BUFFER); indexBinding = name; }
}

static void APIENTRY TestBufferData(GLenum target, GLsizeiptr size, const void* bytes, GLenum usage)
{
	CHECK(usage == GL_STATIC_DRAW);
	CHECK(bytes && size > 0);
	CHECK(target == GL_ARRAY_BUFFER ? arrayBinding != 0 : indexBinding != 0);
	uploads++;
	uploadedBytes += size;
}

static void APIENTRY TestDeleteBuffers(GLsizei count, const GLuint* names)
{
	CHECK(count == kNumGeometryBuffers && names[0]);
	deletions++;
}

int main(void)
{
	gGenBuffers = TestGenBuffers;
	gBindBuffer = TestBindBuffer;
	gBufferData = TestBufferData;
	gDeleteBuffers = TestDeleteBuffers;
	gGeometryBuffersAvailable = true;
	OGLPoint3D points[3] = {{0}};
	OGLTextureCoord uvs[3] = {{0}};
	MOTriangleIndecies indices[1] = {{{0, 1, 2}}};
	MOVertexArrayData mesh = {0};
	mesh.numPoints = 3;
	mesh.numTriangles = 1;
	mesh.points = points;
	mesh.uvs = uvs;
	mesh.triangles = indices;
	mesh.gpuResident = true;

	MO_UploadGeometryBuffers(&mesh);
	CHECK(generations == 1 && uploads == 3);
	CHECK(uploadedBytes == sizeof(points) + sizeof(uvs) + sizeof(indices));
	CHECK(!arrayBinding && !indexBinding);
	MO_UploadGeometryBuffers(&mesh);
	CHECK(generations == 1 && uploads == 3); // Repeated frames reuse resident data.
	CHECK(!MO_GeometryArray(&mesh, kBufferPoints, points));
	CHECK(arrayBinding == mesh.gpuBuffers[kBufferPoints]);
	CHECK(!MO_GeometryArray(&mesh, kBufferIndices, indices));
	CHECK(indexBinding == mesh.gpuBuffers[kBufferIndices]);
	MO_UnbindGeometryBuffers();
	CHECK(!arrayBinding && !indexBinding);

	MOVertexArrayData dynamicMesh = {0};
	MO_UploadGeometryBuffers(&dynamicMesh);
	CHECK(generations == 1);
	CHECK(MO_GeometryArray(&dynamicMesh, kBufferPoints, points) == points);
	CHECK(!arrayBinding); // Switching to skeletons/particles must restore client pointers.
	CHECK(MO_GeometryArray(&dynamicMesh, kBufferIndices, indices) == indices);
	CHECK(!indexBinding);

	MO_InvalidateGeometryBuffers(&mesh);
	CHECK(deletions == 1 && !mesh.gpuBuffers[0] && mesh.gpuResident);
	MO_InvalidateGeometryBuffers(&mesh);
	CHECK(deletions == 1); // Disposal after invalidation cannot delete twice.
	points[0].x = 42;
	MO_UploadGeometryBuffers(&mesh);
	CHECK(generations == 2 && uploads == 6); // Recycled terrain/edited UVs upload again.
	MO_InvalidateGeometryBuffers(&mesh);

	pendingError = GL_OUT_OF_MEMORY;
	MO_UploadGeometryBuffers(&mesh);
	CHECK(!mesh.gpuBuffers[0] && !mesh.gpuResident && deletions == 3);
	CHECK(MO_GeometryArray(&mesh, kBufferPoints, points) == points);
	MO_UploadGeometryBuffers(&mesh);
	CHECK(generations == 3); // Failed allocation falls back without retrying every frame.

	mesh.gpuResident = true;
	gGeometryBuffersAvailable = false;
	MO_UploadGeometryBuffers(&mesh);
	CHECK(generations == 3);
	CHECK(MO_GeometryArray(&mesh, kBufferPoints, points) == points);
	puts("Geometry buffer regression checks passed");
	return 0;
}
