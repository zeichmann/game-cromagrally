#include "game.h"
#include <math.h>


// The starting-line model contains two tusks made of five octagonal rings and a tip.
enum { TUSK_RINGS = 5, TUSK_POINTS = 41, TUSK_TRIANGLES = 72 };
enum { TUSK_SUBDIVISIONS = 4, TUSK_FACE_POINTS = (TUSK_SUBDIVISIONS+1)*(TUSK_SUBDIVISIONS+2)/2 };


static int TuskRing(OGLPoint3D point)
{
	static const float limits[] = {100, 1200, 2100, 2610};
	for (int ring = 0; ring < SDL_arraysize(limits); ring++)
	{
		if (point.y < limits[ring])
			return ring;
	}
	return TUSK_RINGS-1;
}


static OGLColorRGBA_Byte TuskShade(const OGLPoint3D* point, const OGLVector3D* normal)
{
	const OGLVector3D sun = {-0.34f, 0.81f, 0.48f};
	const float light = 0.70f + 0.30f*fmaxf(0, OGLVector3D_Dot(normal, &sun));
	const float dust = fmaxf(0, 1-point->y/710.0f);
	return (OGLColorRGBA_Byte)
	{
		(uint8_t)(255*light*(1-0.055f*dust)),
		(uint8_t)(255*light*(1-0.13f*dust)),
		(uint8_t)(255*light*(1-0.24f*dust)),
		255,
	};
}


static void AddTuskFace(const MOVertexArrayData* src, const GLuint indices[3],
						const OGLTextureCoord uv[3], MOVertexArrayData* mesh)
{
	GLuint grid[TUSK_SUBDIVISIONS+1][TUSK_SUBDIVISIONS+1];
	for (int row = 0; row <= TUSK_SUBDIVISIONS; row++)
		for (int col = 0; col <= TUSK_SUBDIVISIONS-row; col++)
		{
			const float u = (float)row/TUSK_SUBDIVISIONS;
			const float v = (float)col/TUSK_SUBDIVISIONS;
			const float weights[] = {1-u-v, u, v};
			OGLPoint3D p = {0};
			OGLVector3D normal = {0};
			OGLTextureCoord tex = {0};
			for (int corner = 0; corner < 3; corner++)
			{
				const OGLPoint3D vertex = src->points[indices[corner]];
				const OGLVector3D n = src->normals[indices[corner]];
				const float w = weights[corner];
				p.x += w*vertex.x;
				p.y += w*vertex.y;
				p.z += w*vertex.z;
				normal.x += w*n.x;
				normal.y += w*n.y;
				normal.z += w*n.z;
				tex.u += w*uv[corner].u;
				tex.v += w*uv[corner].v;
			}

			// Interpolate the three tangent-plane projections to round the long
			// facets without changing the original rings or the texture seam.
			OGLPoint3D curved = p;
			for (int corner = 0; corner < 3; corner++)
			{
				const OGLPoint3D vertex = src->points[indices[corner]];
				const OGLVector3D n = src->normals[indices[corner]];
				const float planeDistance = (p.x-vertex.x)*n.x + (p.y-vertex.y)*n.y + (p.z-vertex.z)*n.z;
				const float correction = 0.72f*weights[corner]*planeDistance;
				curved.x -= correction*n.x;
				curved.y -= correction*n.y;
				curved.z -= correction*n.z;
			}
			const GLuint i = mesh->numPoints++;
			grid[row][col] = i;
			OGLVector3D_Normalize(&normal, &mesh->normals[i]);
			mesh->points[i] = curved;
			mesh->uvs[i] = tex;
			mesh->colorsByte[i] = TuskShade(&curved, &mesh->normals[i]);
		}

	for (int row = 0; row < TUSK_SUBDIVISIONS; row++)
		for (int col = 0; col < TUSK_SUBDIVISIONS-row; col++)
		{
			const GLuint a = grid[row][col];
			const GLuint b = grid[row+1][col];
			const GLuint c = grid[row][col+1];
			mesh->triangles[mesh->numTriangles++] = (MOTriangleIndecies) {{a, b, c}};
			if (row+col < TUSK_SUBDIVISIONS-1)
				mesh->triangles[mesh->numTriangles++] = (MOTriangleIndecies) {{b, grid[row+1][col+1], c}};
		}
}


static void UnwrapTusk(MOVertexArrayData* tusk, MOMaterialObject* ivory)
{
	OGLPoint3D centers[TUSK_RINGS+1] = {0};
	float length[TUSK_RINGS+1] = {0};
	OGLTextureCoord uv[TUSK_POINTS];
	int counts[TUSK_RINGS+1] = {0};
	int rings[TUSK_POINTS];
	const float side = tusk->points[0].x < 0 ? -1.0f : 1.0f;

	for (int i = 0; i < TUSK_POINTS; i++)
	{
		const OGLPoint3D p = tusk->points[i];
		const int ring = fabsf(p.x) < 350.0f ? TUSK_RINGS : TuskRing(p);
		rings[i] = ring;
		centers[ring].x += side*p.x;
		centers[ring].y += p.y;
		centers[ring].z += side*p.z;
		counts[ring]++;
	}
	for (int i = 0; i <= TUSK_RINGS; i++)
	{
		if (counts[i] == 0)
			return;
		centers[i].x /= counts[i];
		centers[i].y /= counts[i];
		centers[i].z /= counts[i];
		if (i > 0)
			length[i] = length[i-1] + OGLPoint3D_Distance(&centers[i-1], &centers[i]);
	}

	// Follow the curved centerline so the ivory grain runs from root to tip.
	for (int i = 0; i < TUSK_POINTS; i++)
	{
		const int ring = rings[i];
		const OGLPoint3D p = tusk->points[i];
		const OGLPoint3D prev = centers[GAME_MAX(0, ring-1)];
		const OGLPoint3D next = centers[GAME_MIN(TUSK_RINGS, ring+1)];
		const float x = side*p.x - centers[ring].x;
		const float y = p.y - centers[ring].y;
		const float z = side*p.z - centers[ring].z;
		const float dx = next.x-prev.x;
		const float dy = next.y-prev.y;
		const float across = (dy*x - dx*y) / hypotf(dx, dy);
		uv[i] = (OGLTextureCoord)
		{
			0.5f + atan2f(z, across)/PI2,
			length[ring] / 2050.0f,
		};
	}

	const int points = TUSK_FACE_POINTS * tusk->numTriangles;
	const int triangles = TUSK_SUBDIVISIONS*TUSK_SUBDIVISIONS*tusk->numTriangles;
	MOVertexArrayData finish =
	{
		.numMaterials = 1,
		.materials = {MO_GetNewReference(ivory)},
		.pointCapacity = points,
		.triangleCapacity = triangles,
		.gpuResident = true,
		.points = AllocPtr(points * sizeof(*finish.points)),
		.normals = AllocPtr(points * sizeof(*finish.normals)),
		.uvs = AllocPtr(points * sizeof(*finish.uvs)),
		.colorsByte = AllocPtr(points * sizeof(*finish.colorsByte)),
		.triangles = AllocPtr(triangles * sizeof(*finish.triangles)),
	};
	for (int i = 0; i < tusk->numTriangles; i++)
	{
		const GLuint* source = tusk->triangles[i].vertexIndices;
		float low = 1.0f;
		float high = 0.0f;
		for (int v = 0; v < 3; v++)
		{
			if (rings[source[v]] == TUSK_RINGS)
				continue;
			low = fminf(low, uv[source[v]].u);
			high = fmaxf(high, uv[source[v]].u);
		}
		const bool seam = high-low > 0.5f;
		const float tip = (high + low + (seam ? 1.0f : 0.0f))*0.5f;
		OGLTextureCoord faceUV[3];
		for (int v = 0; v < 3; v++)
		{
			const GLuint from = source[v];
			faceUV[v] = uv[from];
			if (rings[from] == TUSK_RINGS)
				faceUV[v].u = tip;
			else if (seam && uv[from].u < 0.5f)
				faceUV[v].u += 1.0f;
		}
		AddTuskFace(tusk, source, faceUV, &finish);
	}

	GAME_ASSERT(finish.numPoints == points && finish.numTriangles == triangles);
	MO_DisposeObject_Geometry_VertexArray(tusk);
	*tusk = finish;
}


void TextureDesertStartingLine(void)
{
	MOGroupObject* start = gBG3DGroupList[MODEL_GROUP_LEVELSPECIFIC][DESERT_ObjType_StartingLine];
	if (!start || start->objectHeader.type != MO_TYPE_GROUP)
		return;

	MOMaterialObject* ivory = NULL;
	for (int i = 0; i < start->objectData.numObjectsInGroup; i++)
	{
		MetaObjectHeader* object = start->objectData.groupContents[i];
		if (object->type != MO_TYPE_GEOMETRY || object->subType != MO_GEOMETRY_SUBTYPE_VERTEXARRAY)
			continue;
		MOVertexArrayData* mesh = &((MOVertexArrayObject*)object)->objectData;
		if (mesh->numPoints != TUSK_POINTS || mesh->numTriangles != TUSK_TRIANGLES || !mesh->normals)
			continue;
		if (!ivory)
		{
			const int previousFlags = gLoadTextureFlags;
			gLoadTextureFlags |= kLoadTextureFlags_NoGammaFix;
			ivory = MO_GetTextureFromFile(":TexturesHD:desert-ivory.png", GL_RGB);
			gLoadTextureFlags = previousFlags;
			OGL_ConfigureHighQualityTexture();
		}
		UnwrapTusk(mesh, ivory);
	}
	if (ivory)
		MO_DisposeObjectReference(ivory);
}
