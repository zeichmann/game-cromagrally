// Terrain sampling and world-space detail for the compatibility renderer.
#include "game.h"
#include "framesharpen.h"
#include "shaderprogram.h"
#include <SDL3/SDL_opengl_glext.h>

static struct
{
	const char* path;
	MOMaterialObject* material;
	GLint previousBinding;
	GLint wrap;
} gDesertTextures[] =
{
	{":TexturesHD:desert-detail.png", NULL, 0, GL_REPEAT},
	{":TexturesHD:desert-sandstone.png", NULL, 0, GL_MIRRORED_REPEAT},
	{":TexturesHD:desert-fractured-rock.png", NULL, 0, GL_MIRRORED_REPEAT},
};
static GLuint gTerrainProgram;
static GLint gMinBlendWidthLocation;
static GLint gUseDetailLocation;
static GLint gUseFogLocation;
static GLint gPreviousProgram;
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
	"uniform sampler2D sandstoneImage;\n"
	"uniform sampler2D fracturedRockImage;\n"
	"uniform float sandstoneBedHeight;\n"
	"uniform float tileSize;\n"
	"uniform float minBlendWidth;\n"
	"uniform bool useDetail;\n"
	"uniform bool useFog;\n"
	"varying vec2 terrainUV;\n"
	"varying vec3 worldPosition;\n"
	"varying vec4 vertexColor;\n"
	"varying float viewDepth;\n"
	"const vec3 sunDirection = vec3(-0.47, 0.70, -0.54);\n"
	"vec3 projectMaterial(sampler2D image, vec3 uv, vec3 weight) {\n"
	"    return (texture2D(image, uv.zy).rgb * weight.x\n"
	"          + texture2D(image, uv.xz).rgb * weight.y\n"
	"          + texture2D(image, uv.xy).rgb * weight.z) / dot(weight, vec3(1.0));\n"
	"}\n"
	"vec3 sandstone(vec3 normal, vec3 weight) {\n"
	"    vec3 p = worldPosition;\n"
	"    float bed = p.y + 90.0 * sin(p.x * 0.00058 + p.z * 0.00087)\n"
	"                    + 35.0 * sin(p.z * 0.0022 - p.x * 0.0016);\n"
	"    vec3 uv = vec3(p.x / 990.0, bed / 680.0, p.z / 990.0);\n"
	"    vec3 grain = projectMaterial(sandstoneImage, uv, weight);\n"
	"    float phase = (bed + (grain.g - 0.64) * 96.0) / sandstoneBedHeight;\n"
	"    float band = fract(phase);\n"
	"    float deposit = fract(sin(floor(phase) * 58.739 + 9.1) * 2137.314);\n"
	"    float minerals = 0.5 + 0.5 * sin(p.x * 0.0006 - p.z * 0.0011 + floor(phase) * 3.03);\n"
	"    float edge = clamp(fwidth(phase) * 0.60, 0.010, 0.13);\n"
	"    float iron = 0.45 + 0.13 * deposit;\n"
	"    float rust = smoothstep(iron-edge, iron+edge, band)\n"
	"               * (1.0 - smoothstep(iron+0.15+0.21*deposit-edge, iron+0.15+0.21*deposit+edge, band));\n"
	"    float ochre = smoothstep(0.25-edge, 0.25+edge, band)\n"
	"                * (1.0 - smoothstep(0.87-edge, 0.87+edge, band));\n"
	"    vec3 color = grain * mix(vec3(1.09, 1.07, 1.04), vec3(1.02, 0.98, 0.92), ochre);\n"
	"    float ironStain = smoothstep(0.12, 0.80, 0.63*deposit + 0.37*minerals);\n"
	"    color = mix(color, grain * vec3(1.04, 0.81, 0.71), rust * (0.20 + 0.38*ironStain));\n"
	"    float seam = abs(fract(phase + 0.5) - 0.5);\n"
	"    float ledgeShade = mix(0.87, 1.0, smoothstep(0.006, 0.039 + edge, seam));\n"
	"    float sun = max(dot(normal, sunDirection), 0.0);\n"
	"    float light = (0.77 + 0.31 * sun) * (0.82 + 0.18 * smoothstep(-0.85, 0.08, normal.y));\n"
	"    if (terrainUV.x < -1.5)\n"
	"        return mix(grain, vec3(0.83, 0.71, 0.55), 0.76) * light;\n"
	"    vec3 slabUV = vec3((p.x + 0.16*p.z)/2420.0, (p.y + 0.085*p.x - 0.068*p.z)/2050.0,\n"
	"                       (p.z - 0.16*p.x)/2690.0);\n"
	"    vec3 slabs = projectMaterial(fracturedRockImage, slabUV, weight);\n"
	"    float lithology = 0.5 + 0.5*sin(p.x*0.00078 + p.z*0.00113 + p.y*0.00032);\n"
	"    slabs *= mix(vec3(1.03, 0.91, 0.82), vec3(0.99, 1.04, 1.11), lithology);\n"
	"    float exposure = 1.0 - smoothstep(0.35, 0.91, abs(normal.y));\n"
	"    color = mix(color*ledgeShade, slabs, 0.48 + 0.43*exposure);\n"
	"    float weathering = terrainUV.x < 0.0 ? terrainUV.y : 1.0;\n"
	"    return color * light * weathering;\n"
	"}\n"
	"vec3 duneColor(float grain) {\n"
	"    vec2 wind = worldPosition.xz;\n"
	"    vec3 normal = normalize(vec3(vertexColor.r*2.0 - 1.0, 1.0, vertexColor.g*2.0 - 1.0));\n"
	"    float sun = max(dot(normal, sunDirection), 0.0);\n"
	"    float phase = dot(wind, vec2(0.0034, 0.0037))\n"
	"                + 0.19*sin(wind.x*0.0011 - wind.y*0.0013 + worldPosition.y*0.0021);\n"
	"    float rippleFade = 1.0 - smoothstep(0.09, 0.46, fwidth(phase));\n"
	"    float ripple = cos(phase*6.2831853) * rippleFade;\n"
	"    float shade = (0.67 + 0.49*sun)*(1.0 + 0.045*ripple + 0.43*grain);\n"
	"    return vec3(0.95, 0.73, 0.43)*shade;\n"
	"}\n"
	"vec3 agave(vec3 normal) {\n"
	"    float u = (terrainUV.x + 4.0) * 1.25;\n"
	"    float v = terrainUV.y;\n"
	"    float edge = abs(u - 0.5) * 2.0;\n"
	"    float midrib = 1.0 - smoothstep(0.014, 0.065, edge);\n"
	"    vec3 green = mix(vec3(0.12, 0.29, 0.084), vec3(0.36, 0.55, 0.21), smoothstep(0.02, 0.90, v));\n"
	"    green = mix(green, vec3(0.61, 0.66, 0.30), 0.56 * smoothstep(0.79, 1.0, edge) + 0.15 * midrib);\n"
	"    float grain = 0.96 + 0.04*sin(130.0*u + 8.0*v + sin(21.0*v));\n"
	"    float sun = dot(normal, normalize(vec3(-0.50, 0.84, -0.28)));\n"
	"    return green * grain * (0.77 + 0.23*abs(sun) + 0.10*max(sun, 0.0));\n"
	"}\n"
	"void main() {\n"
	// Narrow the blend between enlarged texels. Keep their midpoints, including
	// the half-texel blends between supertiles, and use the full blend at distance.
	"    vec2 texel = terrainUV * tileSize - 0.5;\n"
	"    vec2 width = clamp(fwidth(texel), vec2(minBlendWidth), vec2(1.0));\n"
	"    vec2 blend = clamp((fract(texel) - 0.5) / width + 0.5, 0.0, 1.0);\n"
	"    vec2 sampleUV = (floor(texel) + blend + 0.5) / tileSize;\n"
	"    vec4 color = texture2D(terrainImage, sampleUV) * (useDetail ? vec4(1.0) : vertexColor);\n"
	"    if (useDetail) {\n"
	// The normal of the terrain triangle weights the three world-space projections.
	"        vec3 normal = normalize(cross(dFdx(worldPosition), dFdy(worldPosition)));\n"
	"        vec3 slope = abs(normal);\n"
	"        vec3 weight = slope * slope;\n"
	"        vec3 uv = worldPosition / 1250.0;\n"
	"        vec3 detail = vec3(texture2D(detailImage, uv.zy).r,\n"
	"                           texture2D(detailImage, uv.xz).r,\n"
	"                           texture2D(detailImage, uv.xy).r);\n"
	"        float detailValue = dot(detail - 0.532, weight)\n"
	"                          / max(weight.x + weight.y + weight.z, 0.000001);\n"
	"        color.rgb *= 1.0 + 0.90 * detailValue;\n"
	"        if (terrainUV.x < -2.5)\n"
	"            color.rgb = agave(normal);\n"
	"        else if (vertexColor.a > 0.001)\n"
	"            color.rgb = mix(color.rgb, sandstone(normal, weight), smoothstep(0.0, 0.84, vertexColor.a));\n"
	"        if (vertexColor.b > 0.001)\n"
	"            color.rgb = mix(color.rgb, duneColor(detailValue), smoothstep(0.0, 0.92, vertexColor.b));\n"
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
	gUniform1i(gGetUniformLocation(gTerrainProgram, "sandstoneImage"), 2);
	gUniform1i(gGetUniformLocation(gTerrainProgram, "fracturedRockImage"), 3);
	gUniform1f(gGetUniformLocation(gTerrainProgram, "sandstoneBedHeight"), DESERT_SANDSTONE_BED_HEIGHT);
	gUniform1f(gGetUniformLocation(gTerrainProgram, "tileSize"), SUPERTILE_TEXMAP_SIZE + (HQ_TERRAIN ? 2 : 0));
	gUseProgram((GLuint)previousProgram);
	return true;
}

Boolean OGL_BeginTerrainDetail(void)
{
	const bool canSharpen = OGL_IsFrameSharpeningAvailable();
	const float sharpness = canSharpen ? SDL_clamp(gFrameSharpeningStrength, 0.0f, 1.0f) : 0.0f;
	const bool wantsDetail = UseDesertScenery();
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
		for (int i = 0; i < SDL_arraysize(gDesertTextures); i++)
		{
			gActiveTexture(GL_TEXTURE1 + i);
			glGetIntegerv(GL_TEXTURE_BINDING_2D, &gDesertTextures[i].previousBinding);
			if (!gDesertTextures[i].material)
			{
				const GLboolean textureEnabled = glIsEnabled(GL_TEXTURE_2D);
				const int oldFlags = gLoadTextureFlags;
				gLoadTextureFlags |= kLoadTextureFlags_NoGammaFix;
				gDesertTextures[i].material = MO_GetTextureFromFile(gDesertTextures[i].path, GL_RGB);
				gLoadTextureFlags = oldFlags;
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, gDesertTextures[i].wrap);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, gDesertTextures[i].wrap);
				OGL_ConfigureHighQualityTexture();
				if (!textureEnabled)
					glDisable(GL_TEXTURE_2D);
			}
			glBindTexture(GL_TEXTURE_2D, gDesertTextures[i].material->objectData.textureName[0]);
		}
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

bool OGL_DesertMaterialsActive(void)
{
	return gDetailTextureBound;
}

void OGL_EndTerrainDetail(void)
{
	if (!gTerrainActive)
		return;

	gUseProgram((GLuint)gPreviousProgram);
	if (gDetailTextureBound)
	{
		for (int i = 0; i < SDL_arraysize(gDesertTextures); i++)
		{
			gActiveTexture(GL_TEXTURE1 + i);
			glBindTexture(GL_TEXTURE_2D, (GLuint)gDesertTextures[i].previousBinding);
		}
		gActiveTexture(GL_TEXTURE0);
		gDetailTextureBound = false;
	}
	gTerrainActive = false;
}

void OGL_DisposeTerrainDetail(void)
{
	OGL_EndTerrainDetail();
	for (int i = 0; i < SDL_arraysize(gDesertTextures); i++)
	{
		if (gDesertTextures[i].material)
			MO_DisposeObjectReference(gDesertTextures[i].material);
		gDesertTextures[i].material = NULL;
	}
	if (gTerrainProgram)
		gDeleteProgram(gTerrainProgram);

	gTerrainProgram = 0;
	gTerrainProgramUnavailable = false;
}
