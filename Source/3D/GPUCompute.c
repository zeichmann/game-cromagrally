// OpenGL 4.3 compute backend. The compatibility renderer consumes the output VBOs.
#include "game.h"
#include "gpucompute.h"
#include <SDL3/SDL_opengl_glext.h>
#include <stdio.h>
#include <stdlib.h>

#define COMPUTE_FUNCTIONS(X) \
 X(GenBuffers, PFNGLGENBUFFERSPROC) X(DeleteBuffers, PFNGLDELETEBUFFERSPROC) \
 X(BindBuffer, PFNGLBINDBUFFERPROC) X(BufferData, PFNGLBUFFERDATAPROC) \
 X(GetBufferSubData, PFNGLGETBUFFERSUBDATAPROC) X(BindBufferBase, PFNGLBINDBUFFERBASEPROC) \
 X(CreateShader, PFNGLCREATESHADERPROC) X(ShaderSource, PFNGLSHADERSOURCEPROC) \
 X(CompileShader, PFNGLCOMPILESHADERPROC) X(GetShaderiv, PFNGLGETSHADERIVPROC) \
 X(GetShaderInfoLog, PFNGLGETSHADERINFOLOGPROC) X(DeleteShader, PFNGLDELETESHADERPROC) \
 X(CreateProgram, PFNGLCREATEPROGRAMPROC) X(AttachShader, PFNGLATTACHSHADERPROC) \
 X(LinkProgram, PFNGLLINKPROGRAMPROC) X(GetProgramiv, PFNGLGETPROGRAMIVPROC) \
 X(GetProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC) X(DeleteProgram, PFNGLDELETEPROGRAMPROC) \
 X(UseProgram, PFNGLUSEPROGRAMPROC) X(GetUniformLocation, PFNGLGETUNIFORMLOCATIONPROC) \
 X(Uniform1i, PFNGLUNIFORM1IPROC) X(Uniform1f, PFNGLUNIFORM1FPROC) \
 X(Uniform3f, PFNGLUNIFORM3FPROC) X(DispatchCompute, PFNGLDISPATCHCOMPUTEPROC) \
 X(MemoryBarrier, PFNGLMEMORYBARRIERPROC)
#define DECLARE(name, type) static type c##name;
COMPUTE_FUNCTIONS(DECLARE)
#undef DECLARE

typedef struct { float position[4], normal[4]; uint32_t joints[4]; } SkinVertex;
typedef struct { float positionScale[4], velocityAlpha[4], rotationActive[4]; } GPUParticle;
typedef struct { float heights[4]; int32_t split[4]; } GPUTile;
_Static_assert(sizeof(SkinVertex) == 48, "std430 skin vertex layout");
_Static_assert(sizeof(GPUParticle) == 48, "std430 particle layout");
_Static_assert(sizeof(GPUTile) == 32, "std430 terrain layout");
_Static_assert(sizeof(OGLMatrix4x4) == 64, "std430 matrix layout");
_Static_assert(sizeof(OGLPoint3D) == 12 && sizeof(OGLVector3D) == 12, "packed xyz output");
_Static_assert(sizeof(OGLColorRGBA_Byte) == 4, "packed RGBA output");

static GLuint gSkinProgram, gParticleProgram, gBillboardProgram;
static GLuint gMatrixBuffer, gParticleBuffers[2], gTerrainBuffer;
static Boolean gComputeReady;
int gGPUDeformedVertices;
int gGPUSimulatedParticles;
static Boolean ComputeSelfTest(void);

static void IntUniform(GLuint program, const char* name, int value)
{
	cUniform1i(cGetUniformLocation(program, name), value);
}
static void FloatUniform(GLuint program, const char* name, float value)
{
	cUniform1f(cGetUniformLocation(program, name), value);
}
static void SetBuffer(GLuint* buffer, GLsizeiptr size, const void* data, GLenum usage)
{
	if (!*buffer) cGenBuffers(1, buffer);
	cBindBuffer(GL_SHADER_STORAGE_BUFFER, *buffer);
	cBufferData(GL_SHADER_STORAGE_BUFFER, size, data, usage);
}
static void BindStorage(int binding, GLuint buffer)
{
	cBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, buffer);
}
static Boolean EndCompute(void)
{
	cMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT | GL_SHADER_STORAGE_BARRIER_BIT | GL_BUFFER_UPDATE_BARRIER_BIT);
	cUseProgram(0);
	for (int i=0; i<4; i++) BindStorage(i, 0);
	cBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
	MO_UnbindGeometryBuffers();
	GLenum error = glGetError();
	if (error == GL_NO_ERROR) return true;
	SDL_Log("GPU compute error 0x%x; restoring CPU path", error);
	while (glGetError() != GL_NO_ERROR) {}
	gComputeReady = false;
	return false;
}
static GLuint CompileCompute(const char* path)
{
	long length=0;
	Ptr source=LoadDataFile(path, &length);
	GLuint shader=cCreateShader(GL_COMPUTE_SHADER);
	const GLchar* text=(const GLchar*)source;
	GLint size=(GLint)length, ok=0;
	cShaderSource(shader, 1, &text, &size);
	cCompileShader(shader);
	SafeDisposePtr(source);
	cGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
	char log[2048];
	if (!ok) {
		cGetShaderInfoLog(shader, sizeof(log), NULL, log);
		SDL_Log("%s: %s", path, log);
		cDeleteShader(shader);
		return 0;
	}
	GLuint program=cCreateProgram();
	cAttachShader(program, shader);
	cLinkProgram(program);
	cDeleteShader(shader);
	cGetProgramiv(program, GL_LINK_STATUS, &ok);
	if (!ok) {
		cGetProgramInfoLog(program, sizeof(log), NULL, log);
		SDL_Log("%s link: %s", path, log);
		cDeleteProgram(program);
		return 0;
	}
	return program;
}

void GPU_InitCompute(void)
{
	int major=0, minor=0;
	SDL_sscanf((const char*)glGetString(GL_VERSION), "%d.%d", &major, &minor);
	if (major<4 || (major==4 && minor<3) || SDL_getenv("CMR_DISABLE_GPU_COMPUTE") || SDL_getenv("CMR_DISABLE_GPU_BUFFERS")) {
		SDL_Log("GPU compute unavailable/disabled; using CPU animation and particles");
		if (SDL_getenv("CMR_COMPUTE_SELFTEST")) exit(2);
		return;
	}
#define LOAD(name, type) c##name=(type)SDL_GL_GetProcAddress("gl" #name); if (!c##name) { SDL_Log("Missing gl" #name); if (SDL_getenv("CMR_COMPUTE_SELFTEST")) exit(2); return; }
	COMPUTE_FUNCTIONS(LOAD)
#undef LOAD
	gSkinProgram=CompileCompute(":Shaders:skin.comp");
	gParticleProgram=CompileCompute(":Shaders:particles.comp");
	gBillboardProgram=CompileCompute(":Shaders:billboards.comp");
	gComputeReady=gSkinProgram && gParticleProgram && gBillboardProgram;
	SDL_Log("GPU compute %s on %s / %s", gComputeReady? "enabled":"disabled", glGetString(GL_RENDERER), glGetString(GL_VERSION));
	if (SDL_getenv("CMR_COMPUTE_SELFTEST")) {
		Boolean pass=gComputeReady && ComputeSelfTest();
		SDL_Log("GPU compute self-tests: %s", pass? "PASS":"FAIL");
		exit(pass?0:1);
	}
}

void GPU_ResetParticleTerrain(void)
{
	if (gTerrainBuffer && cDeleteBuffers) cDeleteBuffers(1, &gTerrainBuffer);
	gTerrainBuffer=0;
}
void GPU_ShutdownCompute(void)
{
	GPU_ResetParticleTerrain();
	if (cDeleteBuffers) {
		cDeleteBuffers(1,&gMatrixBuffer);
		cDeleteBuffers(2,gParticleBuffers);
	}
	if (gSkinProgram) cDeleteProgram(gSkinProgram);
	if (gParticleProgram) cDeleteProgram(gParticleProgram);
	if (gBillboardProgram) cDeleteProgram(gBillboardProgram);
	gMatrixBuffer=gParticleBuffers[0]=gParticleBuffers[1]=0;
	gSkinProgram=gParticleProgram=gBillboardProgram=0;
	gComputeReady=false;
}

static void SkinMatrices(const ObjNode* node, int joint, const OGLMatrix4x4* parent, OGLMatrix4x4* matrices)
{
	const SkeletonObjDataType* skeleton=node->Skeleton;
	if (skeleton->JointsAreGlobal) matrices[joint]=skeleton->jointTransformMatrix[joint];
	else OGLMatrix4x4_Multiply(&skeleton->jointTransformMatrix[joint],parent,&matrices[joint]);
	const SkeletonDefType* def=skeleton->skeletonDefinition;
	for (int child=0;child<def->numChildren[joint];child++)
		SkinMatrices(node,def->childIndecies[joint][child],&matrices[joint],matrices);
}

static Boolean PrepareSkinInputs(const SkeletonDefType* skeleton, int meshIndex, MOVertexArrayData* mesh)
{
	if (mesh->gpuSkinInput) return true;
	SkinVertex* vertices=AllocPtrClear(sizeof(SkinVertex)*mesh->numPoints);
	for (int bone=0;bone<skeleton->NumBones;bone++) {
		const BoneDefinitionType* b=&skeleton->Bones[bone];
		for (int p=0;p<b->numPointsAttachedToBone;p++) {
			const DecomposedPointType* point=&skeleton->decomposedPointList[b->pointList[p]];
			for (int ref=0;ref<point->numRefs;ref++) {
				if (point->whichTriMesh[ref]!=meshIndex) continue;
				SkinVertex* vertex=&vertices[point->whichPoint[ref]];
				SDL_memcpy(vertex->position,&point->boneRelPoint,sizeof(OGLPoint3D));
				vertex->position[3]=1;
				int normal=point->whichNormal[ref];
				SDL_memcpy(vertex->normal,&skeleton->decomposedNormalsList[normal],sizeof(OGLVector3D));
				vertex->joints[0]=bone;
				// A shared source normal is transformed separately for each attached bone.
				vertex->joints[1]=bone;
			}
		}
	}
	SetBuffer(&mesh->gpuSkinInput,sizeof(SkinVertex)*mesh->numPoints,vertices,GL_STATIC_DRAW);
	SafeDisposePtr(vertices);
	mesh->gpuResident=true;
	MO_UploadGeometryBuffers(mesh);
	return mesh->gpuBuffers[0]!=0 && mesh->gpuSkinInput!=0;
}

Boolean GPU_SkinSkeleton(ObjNode* node)
{
	if (!node->Skeleton || !node->Skeleton->skeletonDefinition) return false;
	const SkeletonDefType* skeleton=node->Skeleton->skeletonDefinition;
	MOVertexArrayData* meshes=gLocalTriMeshesOfSkelType[node->Type];
	if (gComputeReady) {
		OGLMatrix4x4 matrices[MAX_JOINTS];
		SkinMatrices(node,0,&node->BaseTransformMatrix,matrices);
		SetBuffer(&gMatrixBuffer,sizeof(OGLMatrix4x4)*skeleton->NumBones,matrices,GL_STREAM_DRAW);
		for (int i=0;i<skeleton->numDecomposedTriMeshes;i++) {
			MOVertexArrayData* mesh=&meshes[i];
			if (!PrepareSkinInputs(skeleton,i,mesh)) { EndCompute(); gComputeReady=false; break; }
			cUseProgram(gSkinProgram);
			IntUniform(gSkinProgram,"vertexCount",mesh->numPoints);
			BindStorage(0,mesh->gpuSkinInput); BindStorage(1,gMatrixBuffer);
			BindStorage(2,mesh->gpuBuffers[kBufferPoints]); BindStorage(3,mesh->gpuBuffers[kBufferNormals]);
			cDispatchCompute((mesh->numPoints+63)/64,1,1);
			if (!EndCompute()) break;
			gGPUDeformedVertices+=mesh->numPoints;
		}
		if (gComputeReady) return true;
	}
	// An earlier GPU draw must not leave stale output attached to the CPU fallback.
	for (int i=0;i<skeleton->numDecomposedTriMeshes;i++) {
		MO_InvalidateGeometryBuffers(&meshes[i]);
		meshes[i].gpuResident=false;
	}
	return false;
}

// Optional driver regression: compare every animated pose with the legacy CPU path.
void GPU_ValidateSkin(ObjNode* node)
{
	static Boolean reported[MAX_SKELETON_TYPES];
	int meshCount=node->Skeleton->skeletonDefinition->numDecomposedTriMeshes;
	for (int m=0;m<meshCount;m++) {
		MOVertexArrayData* mesh=&gLocalTriMeshesOfSkelType[node->Type][m];
		size_t size=mesh->numPoints*sizeof(OGLPoint3D);
		float* output=AllocPtr((long)size);
		for (int array=0;array<2;array++) {
			cBindBuffer(GL_SHADER_STORAGE_BUFFER,mesh->gpuBuffers[array==0?kBufferPoints:kBufferNormals]);
			cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,size,output);
			const float* cpu=(const float*)(array==0?(void*)mesh->points:(void*)mesh->normals);
			for (int i=0;i<mesh->numPoints*3;i++) {
				if (!isfinite(output[i]) || fabsf(output[i]-cpu[i])>.01f+fabsf(cpu[i])*.000002f) {
					SDL_Log("GPU skin comparison FAIL type %d mesh %d array %d scalar %d: GPU %.8g CPU %.8g",node->Type,m,array,i,output[i],cpu[i]);
					exit(3);
				}
			}
		}
		SafeDisposePtr(output);
	}
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,0);
	if (!reported[node->Type]) {
		SDL_Log("GPU skin comparison PASS type %d",node->Type);
		reported[node->Type]=true;
	}
}

static void PackParticles(const ParticleGroupType* group, GPUParticle* particles)
{
	SDL_memset(particles,0,sizeof(GPUParticle)*MAX_PARTICLES);
	for (int i=0;i<MAX_PARTICLES;i++) {
		if (!group->isUsed[i]) continue;
		SDL_memcpy(particles[i].positionScale,&group->coord[i],sizeof(OGLPoint3D));
		SDL_memcpy(particles[i].velocityAlpha,&group->delta[i],sizeof(OGLVector3D));
		particles[i].positionScale[3]=group->scale[i];
		particles[i].velocityAlpha[3]=group->alpha[i];
		particles[i].rotationActive[0]=group->rotZ[i];
		particles[i].rotationActive[1]=group->rotDZ[i];
		particles[i].rotationActive[2]=1;
	}
}
static void PrepareTerrain(void)
{
	if (gTerrainBuffer) return;
	extern Byte** gMapSplitMode;
	int width=gMapYCoords?gTerrainTileWidth:0, depth=gMapYCoords?gTerrainTileDepth:0;
	int count=width*depth;
	GPUTile* tiles=AllocPtrClear(sizeof(GPUTile)*(count?count:1));
	for (int z=0;z<depth;z++) for (int x=0;x<width;x++) {
		GPUTile* tile=&tiles[z*width+x];
		tile->heights[0]=gMapYCoords[z][x]; tile->heights[1]=gMapYCoords[z][x+1];
		tile->heights[2]=gMapYCoords[z+1][x+1]; tile->heights[3]=gMapYCoords[z+1][x];
		tile->split[0]=gMapSplitMode[z][x];
	}
	SetBuffer(&gTerrainBuffer,sizeof(GPUTile)*(count?count:1),tiles,GL_STATIC_DRAW);
	SafeDisposePtr(tiles);
}
static void ParticleUniforms(const ParticleGroupType* group, float dt)
{
	IntUniform(gParticleProgram,"particleCount",MAX_PARTICLES);
	IntUniform(gParticleProgram,"particleType",group->type);
	IntUniform(gParticleProgram,"flags",group->flags);
	IntUniform(gParticleProgram,"terrainWidth",gMapYCoords?gTerrainTileWidth:0);
	IntUniform(gParticleProgram,"terrainDepth",gMapYCoords?gTerrainTileDepth:0);
	FloatUniform(gParticleProgram,"tileSize",TERRAIN_POLYGON_SIZE);
	FloatUniform(gParticleProgram,"dt",dt);
	FloatUniform(gParticleProgram,"gravity",group->gravity);
	FloatUniform(gParticleProgram,"decayRate",group->decayRate);
	FloatUniform(gParticleProgram,"fadeRate",group->fadeRate);
	FloatUniform(gParticleProgram,"magnetism",group->magnetism);
	FloatUniform(gParticleProgram,"baseScale",group->baseScale);
}
Boolean GPU_MoveParticleGroup(ParticleGroupType* group, float dt)
{
	if (!gComputeReady) return false;
	GPUParticle particles[MAX_PARTICLES];
	PackParticles(group,particles);
	PrepareTerrain();
	SetBuffer(&gParticleBuffers[0],sizeof(particles),particles,GL_STREAM_DRAW);
	SetBuffer(&gParticleBuffers[1],sizeof(particles),NULL,GL_STREAM_READ);
	cUseProgram(gParticleProgram);
	ParticleUniforms(group,dt);
	BindStorage(0,gParticleBuffers[0]); BindStorage(1,gParticleBuffers[1]); BindStorage(2,gTerrainBuffer);
	cDispatchCompute((MAX_PARTICLES+63)/64,1,1);
	if (!EndCompute()) return false;
	// Gameplay tests particle positions on the CPU (fire, damage, extinguishing).
	// Read back simulation state, never expanded billboard vertices.
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,gParticleBuffers[1]);
	cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(particles),particles);
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,0);
	if (glGetError()!=GL_NO_ERROR) {
		while (glGetError()!=GL_NO_ERROR) {}
		SDL_Log("GPU particle readback failed; restoring CPU path");
		gComputeReady=false;
		return false;
	}
	for (int i=0;i<MAX_PARTICLES;i++) {
		if (group->isUsed[i]) gGPUSimulatedParticles++;
		group->isUsed[i]=particles[i].rotationActive[2]>0.5f;
		if (!group->isUsed[i]) continue;
		SDL_memcpy(&group->coord[i],particles[i].positionScale,sizeof(OGLPoint3D));
		SDL_memcpy(&group->delta[i],particles[i].velocityAlpha,sizeof(OGLVector3D));
		group->scale[i]=particles[i].positionScale[3];
		group->alpha[i]=particles[i].velocityAlpha[3];
		group->rotZ[i]=particles[i].rotationActive[0];
	}
	return true;
}
Boolean GPU_DrawParticleGroup(ParticleGroupType* group, const OGLPoint3D* camera)
{
	MOVertexArrayData* mesh=&group->geometryObj->objectData;
	if (gComputeReady) {
		GPUParticle particles[MAX_PARTICLES];
		PackParticles(group,particles); // Includes emitters that ran after simulation.
		SetBuffer(&gParticleBuffers[0],sizeof(particles),particles,GL_STREAM_DRAW);
		mesh->numPoints=MAX_PARTICLES*4; mesh->numTriangles=MAX_PARTICLES*2;
		mesh->gpuResident=true;
		MO_UploadGeometryBuffers(mesh);
		if (!mesh->gpuBuffers[0]) { EndCompute(); gComputeReady=false; }
		else {
			cUseProgram(gBillboardProgram);
			IntUniform(gBillboardProgram,"particleCount",MAX_PARTICLES);
			FloatUniform(gBillboardProgram,"baseScale",group->baseScale);
			cUniform3f(cGetUniformLocation(gBillboardProgram,"camera"),camera->x,camera->y,camera->z);
			BindStorage(0,gParticleBuffers[0]); BindStorage(1,mesh->gpuBuffers[kBufferPoints]);
			BindStorage(2,mesh->gpuBuffers[kBufferColorsByte]);
			cDispatchCompute((MAX_PARTICLES+63)/64,1,1);
			if (EndCompute()) {
				glBlendFunc(group->srcBlend,group->dstBlend);
				MO_DrawObject(group->geometryObj);
				return true;
			}
		}
	}
	MO_InvalidateGeometryBuffers(mesh);
	mesh->gpuResident=false;
	return false;
}

// Driver-level numerical regression checks; set CMR_COMPUTE_SELFTEST=1 to run.
static Boolean ComputeSelfTest(void)
{
	Boolean pass=true;
#define VERIFY(test) do { if (!(test)) { SDL_Log("Compute self-test failed at line %d: %s",__LINE__,#test); pass=false; } } while (0)
	GLuint input=0, positions=0, normals=0, colors=0;
	SkinVertex vertices[2]={0};
	vertices[0].position[0]=1; vertices[0].position[1]=2; vertices[0].position[2]=3; vertices[0].position[3]=1;
	vertices[0].normal[1]=1;
	vertices[1]=vertices[0]; vertices[1].joints[0]=1; vertices[1].joints[1]=1;
	OGLMatrix4x4 matrices[2];
	OGLMatrix4x4_SetIdentity(&matrices[0]);
	matrices[0].value[M03]=10; matrices[0].value[M13]=20; matrices[0].value[M23]=30;
	OGLMatrix4x4_SetRotate_Z(&matrices[1],PI/2);
	SetBuffer(&input,sizeof(vertices),vertices,GL_STATIC_DRAW);
	SetBuffer(&gMatrixBuffer,sizeof(matrices),matrices,GL_STREAM_DRAW);
	SetBuffer(&positions,6*sizeof(float),NULL,GL_STREAM_READ);
	SetBuffer(&normals,6*sizeof(float),NULL,GL_STREAM_READ);
	cUseProgram(gSkinProgram); IntUniform(gSkinProgram,"vertexCount",2);
	BindStorage(0,input); BindStorage(1,gMatrixBuffer); BindStorage(2,positions); BindStorage(3,normals);
	cDispatchCompute(1,1,1); VERIFY(EndCompute());
	float actual[6], actualNormals[6];
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,positions); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(actual),actual);
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,normals); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(actualNormals),actualNormals);
	for (int i=0;i<2;i++) {
		OGLPoint3D expected;
		OGLPoint3D_Transform((OGLPoint3D*)vertices[i].position,&matrices[i],&expected);
		OGLVector3D expectedNormal;
		OGLVector3D_Transform((OGLVector3D*)vertices[i].normal,&matrices[i],&expectedNormal);
		for (int a=0;a<3;a++) {
			VERIFY(fabsf(actual[3*i+a]-((float*)&expected)[a])<0.0001f);
			VERIFY(fabsf(actualNormals[3*i+a]-((float*)&expectedNormal)[a])<0.0001f);
		}
	}

	ParticleGroupType group={0};
	group.type=PARTICLE_TYPE_FALLINGSPARKS; group.flags=PARTICLE_FLAGS_BOUNCE;
	group.baseScale=1; group.gravity=10; group.decayRate=.5f; group.fadeRate=.2f;
	GPUParticle particles[MAX_PARTICLES]={0};
	particles[0]=(GPUParticle){{100,100,100,1},{2,3,4,.8f},{.25f,2,1,0}};
	particles[1]=(GPUParticle){{100,0,100,1},{0,-10,0,1},{0,0,1,0}};
	particles[3]=(GPUParticle){{100,100,100,.01f},{0,0,0,1},{0,0,1,0}};
	particles[4]=(GPUParticle){{100,100,100,1},{0,0,0,.01f},{0,0,1,0}};
	// A sloped tile tests both its plane height and reflection normal.
	GPUTile tile={{0,80,240,160},{0}};
	SetBuffer(&gTerrainBuffer,sizeof(tile),&tile,GL_STATIC_DRAW);
	for (int split=0;split<2;split++) {
		tile.split[0]=split;
		SetBuffer(&gTerrainBuffer,sizeof(tile),&tile,GL_STATIC_DRAW);
		SetBuffer(&gParticleBuffers[0],sizeof(particles),particles,GL_STREAM_DRAW);
		SetBuffer(&gParticleBuffers[1],sizeof(particles),NULL,GL_STREAM_READ);
		cUseProgram(gParticleProgram); ParticleUniforms(&group,.1f);
		IntUniform(gParticleProgram,"terrainWidth",1); IntUniform(gParticleProgram,"terrainDepth",1);
		BindStorage(0,gParticleBuffers[0]); BindStorage(1,gParticleBuffers[1]); BindStorage(2,gTerrainBuffer);
		cDispatchCompute((MAX_PARTICLES+63)/64,1,1); VERIFY(EndCompute());
		GPUParticle result[MAX_PARTICLES];
		cBindBuffer(GL_SHADER_STORAGE_BUFFER,gParticleBuffers[1]); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(result),result);
		VERIFY(fabsf(result[0].positionScale[0]-100.2f)<.001f);
		VERIFY(fabsf(result[0].positionScale[1]-100.2f)<.001f);
		VERIFY(fabsf(result[0].positionScale[2]-100.4f)<.001f);
		VERIFY(fabsf(result[0].positionScale[3]-.95f)<.0001f);
		VERIFY(fabsf(result[0].velocityAlpha[3]-.78f)<.0001f);
		VERIFY(fabsf(result[0].rotationActive[0]-.45f)<.0001f);
		VERIFY(fabsf(result[1].positionScale[1]-40)<.001f);
		VERIFY(fabsf(result[1].velocityAlpha[1]-4.4f)<.001f);
		VERIFY(fabsf(result[1].velocityAlpha[0]-(-.1f/sqrtf(1.05f)*300))<.001f);
		VERIFY(!result[2].rotationActive[2] && !result[3].rotationActive[2] && !result[4].rotationActive[2]);
	}
	// Gravitational interaction uses a stable snapshot, not in-place races.
	SDL_memset(particles,0,sizeof(particles));
	particles[0]=(GPUParticle){{0,0,0,1},{0,0,0,1},{0,0,1,0}};
	particles[1]=(GPUParticle){{10,0,0,1},{0,0,0,1},{0,0,1,0}};
	group.type=PARTICLE_TYPE_GRAVITOIDS; group.flags=PARTICLE_FLAGS_DONTCHECKGROUND;
	group.gravity=group.decayRate=group.fadeRate=0; group.magnetism=100;
	SetBuffer(&gParticleBuffers[0],sizeof(particles),particles,GL_STREAM_DRAW);
	cUseProgram(gParticleProgram); ParticleUniforms(&group,.1f);
	BindStorage(0,gParticleBuffers[0]); BindStorage(1,gParticleBuffers[1]); BindStorage(2,gTerrainBuffer);
	cDispatchCompute((MAX_PARTICLES+63)/64,1,1); VERIFY(EndCompute());
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,gParticleBuffers[1]); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(particles),particles);
	VERIFY(fabsf(particles[0].positionScale[0]-.01f)<.0001f);
	VERIFY(fabsf(particles[1].positionScale[0]-9.99f)<.0001f);

	SDL_memset(particles,0,sizeof(particles));
	particles[0]=(GPUParticle){{0,0,0,1},{0,0,0,.5f},{0,0,1,0}};
	SetBuffer(&gParticleBuffers[0],sizeof(particles),particles,GL_STREAM_DRAW);
	SetBuffer(&positions,MAX_PARTICLES*12*sizeof(float),NULL,GL_STREAM_READ);
	SetBuffer(&colors,MAX_PARTICLES*4*sizeof(uint32_t),NULL,GL_STREAM_READ);
	cUseProgram(gBillboardProgram);
	IntUniform(gBillboardProgram,"particleCount",MAX_PARTICLES); FloatUniform(gBillboardProgram,"baseScale",2);
	cUniform3f(cGetUniformLocation(gBillboardProgram,"camera"),0,0,-10);
	BindStorage(0,gParticleBuffers[0]); BindStorage(1,positions); BindStorage(2,colors);
	cDispatchCompute((MAX_PARTICLES+63)/64,1,1); VERIFY(EndCompute());
	float quad[24]; uint32_t rgba[8];
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,positions); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(quad),quad);
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,colors); cGetBufferSubData(GL_SHADER_STORAGE_BUFFER,0,sizeof(rgba),rgba);
	const float expectedQuad[12]={-2,2,0,-2,-2,0,2,-2,0,2,2,0};
	for (int i=0;i<12;i++) VERIFY(fabsf(quad[i]-expectedQuad[i])<.0001f);
	VERIFY((rgba[0]&0x00ffffff)==0x00ffffff);
	VERIFY((rgba[0]>>24)==127 || (rgba[0]>>24)==128);
	VERIFY((rgba[4]>>24)==0); // Unused slots stay invisible.
	cDeleteBuffers(1,&input); cDeleteBuffers(1,&positions); cDeleteBuffers(1,&normals); cDeleteBuffers(1,&colors);
	GPU_ResetParticleTerrain();
	cBindBuffer(GL_SHADER_STORAGE_BUFFER,0);
	VERIFY(glGetError()==GL_NO_ERROR);
#undef VERIFY
	return pass;
}
