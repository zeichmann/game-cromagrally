// Terrain sampling and world-space detail for the compatibility renderer.
#include "game.h"
#include "framesharpen.h"
#include "shaderprogram.h"
#include <SDL3/SDL_opengl_glext.h>

static MOMaterialObject* gDesertDetail;
static GLuint gTerrainProgram;
static GLint gMinBlendWidthLocation;
static GLint gUseDetailLocation;
static GLint gUseFogLocation;
static GLint gPreviousProgram;
static GLint gPreviousDetailTexture;
static bool gTerrainProgramUnavailable;
static bool gDetailSupported;
static bool gTerrainActive;
static bool gDetailTextureBound;

static PFNGLACTIVETEXTUREPROC gActiveTexture;
static PFNGLUSEPROGRAMPROC gUseProgram;
static PFNGLDELETEPROGRAMPROC gDeleteProgram;
static PFNGLGETUNIFORMLOCATIONPROC gGetUniformLocation;
static PFNGLUNIFORM1IPROC gUniform1i;
static PFNGLUNIFORM1FPROC gUniform1f;

static const char kTerrainVertexShader[] =
	"#version 110\n"
	"varying vec2 terrainUV;\n"
	"varying vec3 worldPosition;\n"
	"varying vec4 vertexColor;\n"
	"varying float viewDepth;\n"
	"void main() {\n"
	"    gl_Position = ftransform();\n"
	"    terrainUV = gl_MultiTexCoord0.xy;\n"
	"    worldPosition = gl_Vertex.xyz;\n"
	"    vertexColor = gl_Color;\n"
	"    viewDepth = -(gl_ModelViewMatrix * gl_Vertex).z;\n"
	"}\n";

static const char kTerrainFragmentShader[] =
	"#version 110\n"
	"uniform sampler2D terrainImage;\n"
	"uniform sampler2D detailImage;\n"
	"uniform float tileSize;\n"
	"uniform float minBlendWidth;\n"
	"uniform bool useDetail;\n"
	"uniform bool useFog;\n"
	"varying vec2 terrainUV;\n"
	"varying vec3 worldPosition;\n"
	"varying vec4 vertexColor;\n"
	"varying float viewDepth;\n"
	"void main() {\n"
	// Narrow the blend between enlarged texels. Keep their midpoints, including
	// the half-texel blends between supertiles, and use the full blend at distance.
	"    vec2 texel = terrainUV * tileSize - 0.5;\n"
	"    vec2 width = clamp(fwidth(texel), vec2(minBlendWidth), vec2(1.0));\n"
	"    vec2 blend = clamp((fract(texel) - 0.5) / width + 0.5, 0.0, 1.0);\n"
	"    vec2 sampleUV = (floor(texel) + blend + 0.5) / tileSize;\n"
	"    vec4 color = texture2D(terrainImage, sampleUV) * vertexColor;\n"
	"    if (useDetail) {\n"
	// The normal of the terrain triangle weights the three world-space projections.
	"        vec3 slope = abs(cross(dFdx(worldPosition), dFdy(worldPosition)));\n"
	"        slope /= max(slope.x + slope.y + slope.z, 0.000001);\n"
	"        vec3 weight = slope * slope;\n"
	"        vec3 uv = worldPosition / 1250.0;\n"
	"        vec3 detail = vec3(texture2D(detailImage, uv.zy).r,\n"
	"                           texture2D(detailImage, uv.xz).r,\n"
	"                           texture2D(detailImage, uv.xy).r);\n"
	"        float detailValue = dot(detail - 0.532, weight)\n"
	"                          / max(weight.x + weight.y + weight.z, 0.000001);\n"
	"        color.rgb *= 1.0 + 0.90 * detailValue;\n"
	"    }\n"
	"    if (useFog) {\n"
	"        float visible = clamp((gl_Fog.end - viewDepth) * gl_Fog.scale, 0.0, 1.0);\n"
	"        color.rgb = mix(gl_Fog.color.rgb, color.rgb, visible);\n"
	"    }\n"
	"    gl_FragColor = color;\n"
	"}\n";

void OGL_ConfigureHighQualityTexture(void)
{
	PFNGLGENERATEMIPMAPPROC generateMipmap=(PFNGLGENERATEMIPMAPPROC)SDL_GL_GetProcAddress("glGenerateMipmap");
	if (generateMipmap)
	{
		generateMipmap(GL_TEXTURE_2D);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
	}
	if (SDL_GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic"))
	{
		GLfloat maxAnisotropy=1;
		glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT,&maxAnisotropy);
		glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAX_ANISOTROPY_EXT,fminf(maxAnisotropy,16));
	}
}

static bool InitTerrainProgram(void)
{
	gActiveTexture = (PFNGLACTIVETEXTUREPROC)SDL_GL_GetProcAddress("glActiveTexture");
	gUseProgram = (PFNGLUSEPROGRAMPROC)SDL_GL_GetProcAddress("glUseProgram");
	gDeleteProgram = (PFNGLDELETEPROGRAMPROC)SDL_GL_GetProcAddress("glDeleteProgram");
	gGetUniformLocation = (PFNGLGETUNIFORMLOCATIONPROC)SDL_GL_GetProcAddress("glGetUniformLocation");
	gUniform1i = (PFNGLUNIFORM1IPROC)SDL_GL_GetProcAddress("glUniform1i");
	gUniform1f = (PFNGLUNIFORM1FPROC)SDL_GL_GetProcAddress("glUniform1f");
	if (!gActiveTexture || !gUseProgram || !gDeleteProgram || !gGetUniformLocation || !gUniform1i || !gUniform1f)
		return false;

	gTerrainProgram = OGL_BuildShaderProgram("Terrain textures", kTerrainVertexShader, kTerrainFragmentShader);
	if (!gTerrainProgram)
		return false;

	GLint previousProgram;
	GLint maxTextureSize;
	glGetIntegerv(GL_CURRENT_PROGRAM, &previousProgram);
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
	gDetailSupported = maxTextureSize >= 4096;

	gMinBlendWidthLocation = gGetUniformLocation(gTerrainProgram, "minBlendWidth");
	gUseDetailLocation = gGetUniformLocation(gTerrainProgram, "useDetail");
	gUseFogLocation = gGetUniformLocation(gTerrainProgram, "useFog");

	gUseProgram(gTerrainProgram);
	gUniform1i(gGetUniformLocation(gTerrainProgram, "terrainImage"), 0);
	gUniform1i(gGetUniformLocation(gTerrainProgram, "detailImage"), 1);
	gUniform1f(gGetUniformLocation(gTerrainProgram, "tileSize"), SUPERTILE_TEXMAP_SIZE + (HQ_TERRAIN ? 2 : 0));
	gUseProgram((GLuint)previousProgram);
	return true;
}

Boolean OGL_BeginTerrainDetail(void)
{
	const bool canSharpen = OGL_IsFrameSharpeningAvailable();
	const float sharpness = canSharpen ? SDL_clamp(gFrameSharpeningStrength, 0.0f, 1.0f) : 0.0f;
	const bool wantsDetail = gTrackNum == TRACK_NUM_DESERT && !SDL_getenv("CMR_ORIGINAL_TEXTURES");
	if (gDebugMode == 3 || gTerrainProgramUnavailable || (sharpness == 0.0f && !wantsDetail))
		return false;

	if (!gTerrainProgram && !InitTerrainProgram())
	{
		gTerrainProgramUnavailable = true;
		return false;
	}

	const bool useDetail = wantsDetail && gDetailSupported;
	if (useDetail)
	{
		if (!gDesertDetail)
		{
			const int oldFlags = gLoadTextureFlags;
			gLoadTextureFlags |= kLoadTextureFlags_NoGammaFix;
			gDesertDetail = MO_GetTextureFromFile(":TexturesHD:desert-detail.png", GL_RGBA);
			gLoadTextureFlags = oldFlags;
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
			OGL_ConfigureHighQualityTexture();
		}

		gActiveTexture(GL_TEXTURE1);
		glGetIntegerv(GL_TEXTURE_BINDING_2D, &gPreviousDetailTexture);
		glBindTexture(GL_TEXTURE_2D, gDesertDetail->objectData.textureName[0]);
		gActiveTexture(GL_TEXTURE0);
		gDetailTextureBound = true;
	}

	glGetIntegerv(GL_CURRENT_PROGRAM, &gPreviousProgram);
	gUseProgram(gTerrainProgram);
	gUniform1f(gMinBlendWidthLocation, 1.0f - 0.70f * sharpness);
	gUniform1i(gUseDetailLocation, useDetail);
	gUniform1i(gUseFogLocation, glIsEnabled(GL_FOG));
	gTerrainActive = true;
	return true;
}

void OGL_EndTerrainDetail(void)
{
	if (!gTerrainActive)
		return;

	gUseProgram((GLuint)gPreviousProgram);
	if (gDetailTextureBound)
	{
		gActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, (GLuint)gPreviousDetailTexture);
		gActiveTexture(GL_TEXTURE0);
		gDetailTextureBound = false;
	}
	gTerrainActive = false;
}

void OGL_DisposeTerrainDetail(void)
{
	OGL_EndTerrainDetail();
	if (gDesertDetail)
		MO_DisposeObjectReference(gDesertDetail);
	if (gTerrainProgram)
		gDeleteProgram(gTerrainProgram);

	gDesertDetail = NULL;
	gTerrainProgram = 0;
	gTerrainProgramUnavailable = false;
}
