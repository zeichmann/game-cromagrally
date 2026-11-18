#include "game.h"
#include <math.h>


bool UseDesertScenery(void)
{
	return gTrackNum == TRACK_NUM_DESERT && !SDL_getenv("CMR_ORIGINAL_TEXTURES");
}


static float RockVariation(uint32_t key)
{
	key ^= key >> 16;
	key *= 0x7feb352du;
	key ^= key >> 15;
	key *= 0x846ca68bu;
	key ^= key >> 16;
	return (float)(key & 0xffffu) / 65535.0f;
}


static void ReserveRockMesh(MOVertexArrayData* mesh, int points, int triangles)
{
	if (mesh->numPoints + points > mesh->pointCapacity)
	{
		mesh->pointCapacity = GAME_MAX(mesh->numPoints + points, 2 * mesh->pointCapacity);
		mesh->points = ReallocPtr(mesh->points, mesh->pointCapacity * sizeof(*mesh->points));
		mesh->uvs = ReallocPtr(mesh->uvs, mesh->pointCapacity * sizeof(*mesh->uvs));
		mesh->colorsByte = ReallocPtr(mesh->colorsByte, mesh->pointCapacity * sizeof(*mesh->colorsByte));
	}
	if (mesh->numTriangles + triangles > mesh->triangleCapacity)
	{
		mesh->triangleCapacity = GAME_MAX(mesh->numTriangles + triangles, 2 * mesh->triangleCapacity);
		mesh->triangles = ReallocPtr(mesh->triangles, mesh->triangleCapacity * sizeof(*mesh->triangles));
	}
}


static void SceneryVertex(MOVertexArrayData* mesh, OGLPoint3D point, OGLTextureCoord uv, float rock)
{
	const int i = mesh->numPoints++;
	mesh->points[i] = point;
	mesh->uvs[i] = uv;
	// The terrain shader uses the alpha channel for the rock-to-sand blend.
	mesh->colorsByte[i] = (OGLColorRGBA_Byte) {255, 255, 255, (uint8_t)(255*rock + 0.5f)};
}


static void RockVertex(MOVertexArrayData* mesh, OGLPoint3D point, float surface, float shade)
{
	SceneryVertex(mesh, point, (OGLTextureCoord) {surface, shade}, 1.0f);
}


static void RockTriangle(MOVertexArrayData* mesh, GLuint a, GLuint b, GLuint c)
{
	mesh->triangles[mesh->numTriangles++] = (MOTriangleIndecies) {{a, b, c}};
}


static void RockQuad(MOVertexArrayData* mesh, GLuint a, GLuint b, GLuint c, GLuint d)
{
	RockTriangle(mesh, a, b, c);
	RockTriangle(mesh, a, c, d);
}


static OGLPoint3D MixPoint(OGLPoint3D a, OGLPoint3D b, float t)
{
	return (OGLPoint3D) {a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t, a.z + (b.z-a.z)*t};
}


static bool CutBed(const OGLPoint3D face[3], const float heights[3], float level, OGLPoint3D ends[2])
{
	int count = 0;
	for (int i = 0; i < 3; i++)
	{
		const int j = (i+1) % 3;
		if ((heights[i] < level) != (heights[j] < level))
			ends[count++] = MixPoint(face[i], face[j], (level-heights[i]) / (heights[j]-heights[i]));
	}
	return count == 2;
}


static void AddShelf(MOVertexArrayData* mesh, OGLPoint3D a, OGLPoint3D b,
					OGLPoint3D lower, OGLPoint3D upper, OGLVector3D normal, uint32_t seed)
{
	// Keep the shelf inside its terrain triangle, with the crest near the
	// same plane that supports the tires and the roots cut into the rock.
	enum { COLUMNS = 6, PROFILE = 6 };
	static const float width[] = {0.03f, 0.17f, 0.40f, 0.65f, 0.84f, 0.97f};
	static const float crest[] = {0.0f, 0.62f, 1.0f, 0.94f, 0.70f, 0.0f};
	static const float rise[]  = {1.0f, 0.72f, 0.40f, -0.14f, -0.58f, -0.86f};
	static const float lip[]   = {0.0f, 0.52f, 1.0f, 0.86f, 0.29f, 0.0f};
	static const float shade[] = {0.96f, 1.04f, 1.06f, 0.91f, 0.76f, 0.90f};
	if ((b.z-a.z)*normal.x - (b.x-a.x)*normal.z < 0.0f)
	{
		const OGLPoint3D swap = a;
		a = b;
		b = swap;
	}

	const float depth = 32.0f + 14.0f * RockVariation(seed);
	const float thickness = 77.0f + 57.0f * RockVariation(seed+1);
	ReserveRockMesh(mesh, COLUMNS*PROFILE, 2*(COLUMNS-1)*(PROFILE-1));
	const GLuint base = mesh->numPoints;
	for (int column = 0; column < COLUMNS; column++)
	{
		const OGLPoint3D anchor = MixPoint(a, b, width[column]);
		const float relief = crest[column] * (0.80f + 0.20f * RockVariation(seed+7+column));
		const float offset = 27.0f * (RockVariation(seed+20+column) - 0.5f);
		for (int row = 0; row < PROFILE; row++)
		{
			const float height = rise[row]*thickness + offset;
			const OGLPoint3D edge = height > 0 ? upper : lower;
			const float t = fminf(.96f, fabsf(height)/fmaxf(1.0f, fabsf(edge.y-anchor.y)));
			OGLPoint3D point = MixPoint(anchor, edge, t);
			point.y -= 1.5f + depth*(1.0f - lip[row]*relief);
			RockVertex(mesh, point, -1, shade[row]);
		}
	}

	for (int column = 0; column < COLUMNS-1; column++)
		for (int row = 0; row < PROFILE-1; row++)
		{
			const GLuint i = base + column*PROFILE + row;
			RockQuad(mesh, i, i+PROFILE, i+PROFILE+1, i+1);
		}
}


static void AddStone(MOVertexArrayData* mesh, OGLPoint3D center, float radius, uint32_t seed)
{
	enum { SIDES = 6 };
	ReserveRockMesh(mesh, 2*SIDES+1, 3*SIDES);
	const GLuint base = mesh->numPoints;
	const float turn = RockVariation(seed) * PI2;
	for (int i = 0; i < SIDES; i++)
	{
		const float angle = turn + PI2*i/SIDES;
		const float size = radius * (0.75f + 0.30f*RockVariation(seed+1+i));
		const float dx = cosf(angle)*size;
		const float dz = -sinf(angle)*size;
		const float crest = radius * (0.25f + 0.25f*RockVariation(seed+13+i));
		RockVertex(mesh, (OGLPoint3D){center.x+dx, center.y-radius*.56f, center.z+dz*.73f}, -1, 0.82f);
		RockVertex(mesh, (OGLPoint3D){center.x+dx*.68f, center.y+crest, center.z+dz*.52f}, -1, 1.0f);
	}
	const GLuint top = mesh->numPoints;
	RockVertex(mesh, (OGLPoint3D){center.x+radius*.13f, center.y+radius*.57f, center.z}, -1, 1.02f);
	for (int i = 0; i < SIDES; i++)
	{
		const GLuint foot = base + 2*i;
		const GLuint next = base + 2*((i+1) % SIDES);
		RockQuad(mesh, foot+1, foot, next, next+1);
		RockTriangle(mesh, foot+1, next+1, top);
	}
}


static void AddScree(MOVertexArrayData* mesh, OGLPoint3D a, OGLPoint3D b, OGLVector3D normal, uint32_t seed)
{
	const OGLPoint3D center = MixPoint(a, b, 0.42f + 0.17f*RockVariation(seed));
	const float sideways = hypotf(normal.x, normal.z);
	const float dx = normal.x / sideways;
	const float dz = normal.z / sideways;
	GetTerrainY(center.x + dx*215.0f, center.z + dz*215.0f);
	if (fabsf(gRecentTerrainNormal.y) < 0.90f)
		return;

	for (int i = 0; i < 3; i++)
	{
		const float along = (i-1)*77.0f;
		const float out = 16.0f + 31.0f*RockVariation(seed+8+i);
		const float x = center.x - dz*along + dx*out;
		const float z = center.z + dx*along + dz*out;
		const float y = GetTerrainY(x, z);
		const float radius = i == 1 ? 92.0f : 37.0f + 22.0f*RockVariation(seed+21+i);
		AddStone(mesh, (OGLPoint3D) {x, y, z}, radius, seed+32*i);
	}
}


static float BedElevation(const OGLPoint3D* p)
{
	// Match the gently warped bedding coordinate in TerrainDetail.c.
	return p->y + 90.0f*sinf(p->x*0.00058f + p->z*0.00087f)
	            + 35.0f*sinf(p->z*0.0022f - p->x*0.0016f);
}


typedef struct
{
	OGLPoint3D point;
	OGLTextureCoord uv;
	float bed;
	float relief;
	float rock;
} BedVertex;

static const float kBedCuts[] = {0.0f, 0.09f, 0.21f, 0.44f, 0.72f, 0.91f, 1.0f};
static const float kBedDepth[] = {6, 30, 0, 11, 22, 9, 6};


static BedVertex SampleBedVertex(OGLPoint3D p, OGLTextureCoord uv)
{
	const float probe = 165.0f;
	const float dx = GetTerrainY(p.x-probe, p.z) - GetTerrainY(p.x+probe, p.z);
	const float dz = GetTerrainY(p.x, p.z-probe) - GetTerrainY(p.x, p.z+probe);
	const float gradient = hypotf(dx, dz);
	BedVertex vertex = {.point = p, .uv = uv, .bed = BedElevation(&p)};
	if (gradient > probe*0.68f)
	{
		const float x = dx / gradient;
		const float z = dz / gradient;
		const float aboveToe = p.y-GetTerrainY(p.x+x*probe, p.z+z*probe);
		const float rock = SDL_clamp((aboveToe/probe - 0.16f) / 0.55f, 0, 1);
		vertex.relief = SDL_clamp((aboveToe/probe - 0.32f) / 0.60f, 0, 1);
		vertex.rock = rock*rock*(3.0f-2.0f*rock);
	}
	return vertex;
}


static BedVertex MixBedVertex(BedVertex a, BedVertex b, float t)
{
	return (BedVertex)
	{
		.point = MixPoint(a.point, b.point, t),
		.uv = {a.uv.u+(b.uv.u-a.uv.u)*t, a.uv.v+(b.uv.v-a.uv.v)*t},
		.bed = a.bed+(b.bed-a.bed)*t,
		.relief = a.relief+(b.relief-a.relief)*t,
		.rock = a.rock+(b.rock-a.rock)*t,
	};
}


static int ClipBedPolygon(const BedVertex* points, int count, BedVertex* result, float level, bool above)
{
	int size = 0;
	for (int i = 0; i < count; i++)
	{
		const BedVertex a = points[i];
		const BedVertex b = points[(i+1)%count];
		const bool keepA = above ? a.bed >= level : a.bed < level;
		const bool keepB = above ? b.bed >= level : b.bed < level;
		if (keepA)
			result[size++] = a;
		if (keepA != keepB)
		{
			BedVertex cut = MixBedVertex(a, b, (level-a.bed)/(b.bed-a.bed));
			cut.bed = level;
			result[size++] = cut;
		}
	}
	return size;
}


static void AddBedTriangleDetail(MOVertexArrayData* mesh, const BedVertex face[3],
							float bottom, float top, float depthBottom, float depthTop)
{
	const BedVertex points[] =
	{
		face[0], face[1], face[2],
		MixBedVertex(face[0], face[1], .5f),
		MixBedVertex(face[1], face[2], .5f),
		MixBedVertex(face[2], face[0], .5f),
	};
	ReserveRockMesh(mesh, SDL_arraysize(points), 4);
	const GLuint start = mesh->numPoints;
	for (int i = 0; i < SDL_arraysize(points); i++)
	{
		const BedVertex v = points[i];
		OGLPoint3D p = v.point;
		const float fraction = (v.bed-bottom)/(top-bottom);
		const float depth = depthBottom + (depthTop-depthBottom)*fraction;
		const float weather = 0.78f + 0.22f*sinf(p.x*.0039f + p.z*.0051f + p.y*.0014f)
		                             + 0.19f*sinf(p.x*.0073f - p.z*.0064f);
		// Incise the rock within the collision surface. The triangle's XZ
		// footprint stays on its original terrain facet.
		p.y -= v.relief * depth * weather;
		SceneryVertex(mesh, p, v.uv, v.rock);
	}
	RockTriangle(mesh, start, start+3, start+5);
	RockTriangle(mesh, start+3, start+1, start+4);
	RockTriangle(mesh, start+5, start+4, start+2);
	RockTriangle(mesh, start+3, start+4, start+5);
}


static void AddBedTriangle(MOVertexArrayData* mesh, const BedVertex face[3])
{
	const float low = fminf(face[0].bed, fminf(face[1].bed, face[2].bed));
	const float high = fmaxf(face[0].bed, fmaxf(face[1].bed, face[2].bed));
	const int first = (int)floorf(low/DESERT_SANDSTONE_BED_HEIGHT);
	const int last = (int)floorf(high/DESERT_SANDSTONE_BED_HEIGHT);
	for (int layer = first; layer <= last; layer++)
	{
		const float base = layer * DESERT_SANDSTONE_BED_HEIGHT;
		for (int band = 0; band < SDL_arraysize(kBedCuts)-1; band++)
		{
			const float bottom = base + kBedCuts[band]*DESERT_SANDSTONE_BED_HEIGHT;
			const float top = base + kBedCuts[band+1]*DESERT_SANDSTONE_BED_HEIGHT;
			if (bottom > high || top <= low)
				continue;
			BedVertex above[4], strip[5];
			const int n = ClipBedPolygon(face, 3, above, bottom, true);
			const int size = ClipBedPolygon(above, n, strip, top, false);
			for (int i = 1; i < size-1; i++)
				AddBedTriangleDetail(mesh, (BedVertex[3]){strip[0], strip[i], strip[i+1]},
									bottom, top, kBedDepth[band], kBedDepth[band+1]);
		}
	}
}


static void AddTerracedTerrain(MOVertexArrayData* result, const MOVertexArrayData* terrain)
{
	BedVertex vertices[NUM_VERTICES_IN_SUPERTILE];
	for (int i = 0; i < terrain->numPoints; i++)
		vertices[i] = SampleBedVertex(terrain->points[i], terrain->uvs[i]);

	ReserveRockMesh(result, terrain->numPoints, terrain->numTriangles);
	for (int i = 0; i < terrain->numPoints; i++)
		SceneryVertex(result, vertices[i].point, vertices[i].uv, vertices[i].rock);
	for (int i = 0; i < terrain->numTriangles; i++)
	{
		const GLuint* ids = terrain->triangles[i].vertexIndices;
		const BedVertex a = vertices[ids[0]];
		const BedVertex b = vertices[ids[1]];
		const BedVertex c = vertices[ids[2]];
		const float low = fminf(a.point.y, fminf(b.point.y, c.point.y));
		const float high = fmaxf(a.point.y, fmaxf(b.point.y, c.point.y));
		if (high-low < 275 && a.relief == 0 && b.relief == 0 && c.relief == 0)
		{
			ReserveRockMesh(result, 0, 1);
			RockTriangle(result, ids[0], ids[1], ids[2]);
			continue;
		}

		const OGLPoint3D middle = MixPoint(MixPoint(a.point, b.point, 0.5f), c.point, 1.0f/3.0f);
		const OGLTextureCoord uv = {(a.uv.u+b.uv.u+c.uv.u)/3, (a.uv.v+b.uv.v+c.uv.v)/3};
		const BedVertex center = SampleBedVertex(middle, uv);
		AddBedTriangle(result, (BedVertex[3]){a, b, center});
		AddBedTriangle(result, (BedVertex[3]){b, c, center});
		AddBedTriangle(result, (BedVertex[3]){c, a, center});
	}
}


static void BuildRockFace(MOVertexArrayData* mesh, OGLPoint3D face[3], uint32_t seed)
{
	OGLVector3D normal;
	CalcFaceNormal(&face[0], &face[1], &face[2], &normal);
	if (normal.y < 0.0f || normal.y > 0.84f)
		return;

	const float heights[] = {BedElevation(&face[0]), BedElevation(&face[1]), BedElevation(&face[2])};
	const float low = fminf(heights[0], fminf(heights[1], heights[2]));
	const float high = fmaxf(heights[0], fmaxf(heights[1], heights[2]));
	const int first = (int)ceilf((low+205.0f) / DESERT_SANDSTONE_BED_HEIGHT);
	const int last = (int)floorf((high-100.0f) / DESERT_SANDSTONE_BED_HEIGHT);
	int lower = 0, upper = 0;
	for (int i = 1; i < 3; i++)
	{
		if (face[i].y < face[lower].y)
			lower = i;
		if (face[i].y > face[upper].y)
			upper = i;
	}
	OGLPoint3D ends[2];
	for (int bed = first; bed <= last; bed++)
	{
		const uint32_t variation = seed + (uint32_t)bed*173u;
		const float level = bed * DESERT_SANDSTONE_BED_HEIGHT;
		if (RockVariation(variation) > 0.12f
			|| !CutBed(face, heights, level, ends)
			|| OGLPoint3D_Distance(&ends[0], &ends[1]) < 450.0f)
			continue;
		AddShelf(mesh, ends[0], ends[1], face[lower], face[upper], normal, variation);
	}

	const float baseHeights[] = {face[0].y, face[1].y, face[2].y};
	if (RockVariation(seed+75) < 0.38f && CutBed(face, baseHeights, face[lower].y+120.0f, ends)
		&& OGLPoint3D_Distance(&ends[0], &ends[1]) > 140.0f)
		AddScree(mesh, ends[0], ends[1], normal, seed+81);
}


static float GetCliffSurfaceY(const MOVertexArrayData* mesh, int surfaceTriangles, float x, float z)
{
	float y = -1.0e10f;
	for (int i = 0; i < surfaceTriangles; i++)
	{
		const GLuint* indices = mesh->triangles[i].vertexIndices;
		const OGLPoint3D a = mesh->points[indices[0]];
		const OGLPoint3D b = mesh->points[indices[1]];
		const OGLPoint3D c = mesh->points[indices[2]];
		if (x < fminf(a.x, fminf(b.x, c.x)) || x > fmaxf(a.x, fmaxf(b.x, c.x))
			|| z < fminf(a.z, fminf(b.z, c.z)) || z > fmaxf(a.z, fmaxf(b.z, c.z)))
			continue;
		const float dx1 = b.x-a.x, dz1 = b.z-a.z;
		const float dx2 = c.x-a.x, dz2 = c.z-a.z;
		const float area = dx1*dz2-dx2*dz1;
		if (fabsf(area) < 0.01f)
			continue;
		const float u = ((x-a.x)*dz2 - (z-a.z)*dx2)/area;
		const float v = ((z-a.z)*dx1 - (x-a.x)*dz1)/area;
		if (u >= -0.0001f && v >= -0.0001f && u+v <= 1.0001f)
			y = fmaxf(y, a.y + (b.y-a.y)*u + (c.y-a.y)*v);
	}
	return y > -1.0e10f ? y : GetTerrainY(x, z);
}


static void AddAgave(MOVertexArrayData* mesh, float x, float y, float z, float size, uint32_t seed)
{
	enum { LEAVES = 11, LENGTH = 11, WIDTH = 5 };
	const float spin = RockVariation(seed) * PI2;
	for (int leaf = 0; leaf < LEAVES; leaf++)
	{
		const bool inner = leaf >= 7;
		const float angle = spin + leaf*2.3999632f + 0.50f*RockVariation(seed+leaf+77);
		const float dx = cosf(angle);
		const float dz = sinf(angle);
		const float stretch = size * (0.80f + 0.38f*RockVariation(seed+leaf*3));
		const float span = stretch * (inner ? 0.43f : 1.07f);
		const float height = stretch * (inner ? 1.13f : 0.58f);
		const float width = stretch * (inner ? 0.19f : 0.27f);
		const float curl = (RockVariation(seed+leaf+133)-0.5f)*stretch*0.45f;
		const GLuint base = mesh->numPoints;
		ReserveRockMesh(mesh, LENGTH*WIDTH, 4*(LENGTH-1)*(WIDTH-1));
		for (int j = 0; j < LENGTH; j++)
		{
			const float t = (float)j/(LENGTH-1);
			const float out = span * t * (0.20f + 0.80f*t);
			const float top = height * sinf(t*(inner ? 1.43f : 2.25f)) - stretch * (inner ? 0.06f : 0.16f)*t*t;
			const float halfWidth = width * (0.016f + 1.32f*powf(t, 0.48f)*(1-t));
			for (int k = 0; k < WIDTH; k++)
			{
				const float u = (float)k/(WIDTH-1);
				const float offset = 2*u - 1;
				const float across = offset*halfWidth + curl*t*t;
				const OGLPoint3D p =
				{
					x + dx*out - dz*across,
					y + top + 0.34f*halfWidth*offset*offset,
					z + dz*out + dx*across,
				};
				RockVertex(mesh, p, -4.0f + .8f*u, t);
			}
		}
		for (int j = 0; j < LENGTH-1; j++)
			for (int k = 0; k < WIDTH-1; k++)
			{
				const GLuint i = base + j*WIDTH + k;
				RockQuad(mesh, i, i+1, i+WIDTH+1, i+WIDTH);
				RockQuad(mesh, i+1, i, i+WIDTH, i+WIDTH+1);
			}
	}
}


static bool RockChunkOwnsPoint(const SuperTileMemoryType* tile, float x, float z)
{
	return x >= tile->left && x < tile->left + TERRAIN_SUPERTILE_UNIT_SIZE
		&& z >= tile->back && z < tile->back + TERRAIN_SUPERTILE_UNIT_SIZE;
}


static void AddStartingLineAgaves(SuperTileMemoryType* tile, int surfaceTriangles)
{
	// Arrange the rosettes just outside the footprint of the two tusks.
	// Each root belongs to one streamed chunk even when leaves overhang its edge.
	static const struct { float x, z, size; } plants[] =
	{
		{79135, 89135, 324},
		{78945, 89065, 167},
		{80088, 88872, 262},
		{80270, 88997, 171},
		{75740, 85750, 277},
		{76055, 85822, 193},
	};
	for (int i = 0; i < SDL_arraysize(plants); i++)
	{
		if (RockChunkOwnsPoint(tile, plants[i].x, plants[i].z))
		{
			const float x = plants[i].x;
			const float z = plants[i].z;
			const float y = GetCliffSurfaceY(&tile->cliffMesh, surfaceTriangles, x, z);
			const float stoneX = x + 42.0f;
			const float stoneZ = z + 34.0f;
			const float stoneY = GetCliffSurfaceY(&tile->cliffMesh, surfaceTriangles, stoneX, stoneZ);
			AddStone(&tile->cliffMesh, (OGLPoint3D){stoneX, stoneY-12, stoneZ}, plants[i].size*.20f, 8777u+i);
			AddAgave(&tile->cliffMesh, x, y-12.0f, z, plants[i].size, 2509u+i*7229u);
		}
	}
}


static void AddAmmonite(MOVertexArrayData* mesh, int surfaceTriangles, float x, float z)
{
	enum { SEGMENTS = 82, SIDES = 6 };
	GetTerrainY(x, z);
	const OGLVector3D normal = gRecentTerrainNormal;
	const float spread = hypotf(normal.x, normal.z);
	if (spread < 0.5f || normal.y < 0.05f)
		return;

	ReserveRockMesh(mesh, (SEGMENTS+1)*SIDES, 2*SEGMENTS*(SIDES-1));
	const GLuint start = mesh->numPoints;
	for (int ring = 0; ring <= SEGMENTS; ring++)
	{
		const float t = (float)ring / SEGMENTS;
		const float angle = 0.22f + t*PI2*2.18f;
		const float radius = 8.0f + 164.0f*t;
		const float chamber = 0.84f + 0.16f*cosf(angle*12.0f);
		const float width = (6.0f + 25.0f*t) * chamber;
		for (int side = 0; side < SIDES; side++)
		{
			const float cross = PI*side/(SIDES-1);
			const float r = radius + cosf(cross)*width;
			const float along = r * cosf(angle);
			const float up = r * sinf(angle);
			const float px = x - along*normal.z/spread - up*normal.x*normal.y/spread;
			const float pz = z + along*normal.x/spread - up*normal.z*normal.y/spread;
			const float y = GetCliffSurfaceY(mesh, surfaceTriangles, px, pz)
				+ (sinf(cross)*(4.0f+0.57f*width)-2.6f)/normal.y;
			RockVertex(mesh, (OGLPoint3D){px, y, pz}, -2, 1.0f);
		}
	}
	for (int ring = 0; ring < SEGMENTS; ring++)
		for (int side = 0; side < SIDES-1; side++)
		{
			const GLuint i = start + ring*SIDES + side;
			RockQuad(mesh, i, i+1, i+SIDES+1, i+SIDES);
		}
}


void BuildDesertCliffMesh(SuperTileMemoryType* tile, long startCol, long startRow)
{
	MOVertexArrayData* mesh = &tile->cliffMesh;
	MO_InvalidateGeometryBuffers(mesh);
	mesh->numMaterials = -1;
	mesh->gpuResident = true;
	mesh->numPoints = 0;
	mesh->numTriangles = 0;
	const OGLVector3D previousNormal = gRecentTerrainNormal;
	const MOVertexArrayData* terrain = tile->meshData;
	AddTerracedTerrain(mesh, terrain);
	const int surfaceTriangles = mesh->numTriangles;
	for (int i = 0; i < terrain->numTriangles; i++)
	{
		const MOTriangleIndecies* tri = &terrain->triangles[i];
		OGLPoint3D face[] =
		{
			terrain->points[tri->vertexIndices[0]],
			terrain->points[tri->vertexIndices[1]],
			terrain->points[tri->vertexIndices[2]],
		};
		const uint32_t seed = (uint32_t)startCol*73856093u ^ (uint32_t)startRow*19349663u ^ (uint32_t)i*83492791u;
		BuildRockFace(mesh, face, seed);
	}

	// A fossil set into the inside wall just beyond the start arch.
	const float fossilX = 81270.0f;
	const float fossilZ = 89940.0f;
	if (RockChunkOwnsPoint(tile, fossilX, fossilZ))
		AddAmmonite(mesh, surfaceTriangles, fossilX, fossilZ);
	AddStartingLineAgaves(tile, surfaceTriangles);

	for (int i = 0; i < mesh->numPoints; i++)
	{
		const OGLPoint3D p = mesh->points[i];
		tile->bBox.min.x = fminf(tile->bBox.min.x, p.x);
		tile->bBox.min.y = fminf(tile->bBox.min.y, p.y);
		tile->bBox.min.z = fminf(tile->bBox.min.z, p.z);
		tile->bBox.max.x = fmaxf(tile->bBox.max.x, p.x);
		tile->bBox.max.y = fmaxf(tile->bBox.max.y, p.y);
		tile->bBox.max.z = fmaxf(tile->bBox.max.z, p.z);
	}
	gRecentTerrainNormal = previousNormal;
}
