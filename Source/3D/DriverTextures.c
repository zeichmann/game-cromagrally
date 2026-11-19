#include "game.h"
#include "stb_image.h"

enum
{
	kDriverSkinSize = 256,
	kDriverSkinScale = 4,
	kDetailedSkinSize = kDriverSkinSize * kDriverSkinScale,
};

static int8_t gHideGrain[kDetailedSkinSize][kDetailedSkinSize];
static bool gHideGrainLoaded;

static int ClampIndex(int index, int size)
{
	return SDL_clamp(index, 0, size - 1);
}

static void LoadHideGrain(void)
{
	if (gHideGrainLoaded)
		return;

	int width, height;
	long length;
	Ptr image = LoadDataFile(":TexturesHD:driver-hide-detail.png", &length);
	uint8_t* grayscale = stbi_load_from_memory((const stbi_uc*)image, (int)length, &width, &height, NULL, 1);
	SafeDisposePtr(image);
	GAME_ASSERT(grayscale);

	for (int y = 0; y < kDetailedSkinSize; y++)
	{
		int sy = y * height / kDetailedSkinSize;
		const uint8_t* row = grayscale + sy * width;
		const uint8_t* above = grayscale + ClampIndex(sy - 11, height) * width;
		const uint8_t* below = grayscale + ClampIndex(sy + 11, height) * width;
		for (int x = 0; x < kDetailedSkinSize; x++)
		{
			int sx = x * width / kDetailedSkinSize;
			int mean = (row[ClampIndex(sx - 11, width)] + row[ClampIndex(sx + 11, width)] + above[sx] + below[sx]) / 4;
			gHideGrain[y][x] = (int8_t) SDL_clamp(row[sx] - mean, -32, 32);
		}
	}

	stbi_image_free(grayscale);
	gHideGrainLoaded = true;
}

// Cubic reconstruction keeps the UV atlas layout while reducing the soft
// edges of bilinear magnification. Bound the result to prevent bright halos.
static void ExpandSkinAxis(const uint8_t* source, uint8_t* dest, int channels, bool horizontal)
{
	const int lineCount = horizontal ? kDriverSkinSize : kDetailedSkinSize;
	const int lineStride = horizontal ? kDriverSkinSize * channels : channels;
	const int destLineStride = horizontal ? kDetailedSkinSize * channels : channels;
	const int sampleStride = horizontal ? channels : kDetailedSkinSize * channels;

	for (int i = 0; i < kDetailedSkinSize; i++)
	{
		float pos = (i + .5f) / kDriverSkinScale - .5f;
		int center = (int)floorf(pos);
		float t = pos - center;
		float t2 = t * t;
		const float sharpness = .85f;
		const float leftWeight = -sharpness * t * (1 - t) * (1 - t);
		const float rightWeight = -sharpness * t2 * (1 - t);
		const float lowerWeight = 1 + t2 * ((2 - sharpness) * t + sharpness - 3);
		const float upperWeight = 1 - leftWeight - lowerWeight - rightWeight;
		int left = ClampIndex(center - 1, kDriverSkinSize) * sampleStride;
		int lower = ClampIndex(center, kDriverSkinSize) * sampleStride;
		int upper = ClampIndex(center + 1, kDriverSkinSize) * sampleStride;
		int right = ClampIndex(center + 2, kDriverSkinSize) * sampleStride;

		for (int line = 0; line < lineCount; line++)
		{
			const uint8_t* from = source + line * lineStride;
			uint8_t* to = dest + line * destLineStride + i * sampleStride;
			for (int c = 0; c < channels; c++)
			{
				int a = from[lower + c];
				int b = from[upper + c];
				float value = leftWeight * from[left + c] + lowerWeight * a
					+ upperWeight * b + rightWeight * from[right + c];
				to[c] = (uint8_t) SDL_clamp((int)(value + .5f), SDL_min(a, b), SDL_max(a, b));
			}
		}
	}
}

static float SmoothRamp(float lo, float hi, float value)
{
	const float t = SDL_clamp((value - lo) / (hi - lo), 0.0f, 1.0f);
	return t * t * (3 - 2 * t);
}

static void ShadeSkin(uint8_t* pixels, int channels)
{
	for (int y = 0; y < kDetailedSkinSize; y++)
	{
		// The original atlases put the hair and face above the clothing.
		// The texture buffer starts at the bottom, as OpenGL expects.
		float atlasY = (kDetailedSkinSize - .5f - y) / kDriverSkinScale;
		float clothingRegion = SmoothRamp(118, 132, atlasY);
		float hairRegion = 1 - SmoothRamp(73, 112, atlasY);
		for (int x = 0; x < kDetailedSkinSize; x++, pixels += channels)
		{
			float shade = .299f * pixels[0] + .587f * pixels[1] + .114f * pixels[2];
			// The warm skin hue is similar in light and shadow. Reject it
			// independently of brightness so shaded skin stays smooth.
			float green = fmaxf(pixels[1], 1);
			float redToGreen = pixels[0] / green;
			float blueToGreen = pixels[2] / green;
			float skin = SmoothRamp(1.01f, 1.16f, redToGreen) * (1 - SmoothRamp(1.44f, 1.63f, redToGreen))
				* SmoothRamp(.47f, .65f, blueToGreen) * (1 - SmoothRamp(.86f, .98f, blueToGreen));
			float clothing = clothingRegion * (1 - SmoothRamp(151, 201, shade)) * (1 - skin);
			float hair = hairRegion * (1 - SmoothRamp(75, 151, shade)) * (1 - .75f * skin);
			// Keep the grain neutral so costume colors and face markings survive.
			float relief = clothing * gHideGrain[y][x] * 1.45f;
			relief += hair * gHideGrain[y / 5][x] * .52f;
			for (int c = 0; c < 3; c++)
			{
				float value = pixels[c] + relief * (.4f + pixels[c] / 255.0f);
				pixels[c] = (uint8_t) SDL_clamp((int)(value + .5f), 0, 255);
			}
		}
	}
}

GLuint OGL_TextureMap_LoadDriverSkin(uint8_t* pixels, int* width, int* height, GLenum srcFormat, GLenum dstFormat)
{
	if (SDL_getenv("CMR_ORIGINAL_TEXTURES") || *width != kDriverSkinSize || *height != kDriverSkinSize
		|| (srcFormat != GL_RGB && srcFormat != GL_RGBA))
	{
		return OGL_TextureMap_Load(pixels, *width, *height, srcFormat, dstFormat, GL_UNSIGNED_BYTE);
	}

	LoadHideGrain();
	int channels = srcFormat == GL_RGBA ? 4 : 3;
	uint8_t* rows = (uint8_t*) AllocPtr(kDetailedSkinSize * kDriverSkinSize * channels);
	uint8_t* detailed = (uint8_t*) AllocPtr(kDetailedSkinSize * kDetailedSkinSize * channels);
	GAME_ASSERT(rows && detailed);

	ExpandSkinAxis(pixels, rows, channels, true);
	ExpandSkinAxis(rows, detailed, channels, false);
	SafeDisposePtr((Ptr)rows);
	ShadeSkin(detailed, channels);

	*width = kDetailedSkinSize;
	*height = kDetailedSkinSize;
	GLuint texture = OGL_TextureMap_Load(detailed, *width, *height, srcFormat, dstFormat, GL_UNSIGNED_BYTE);
	OGL_ConfigureHighQualityTexture();
	SafeDisposePtr((Ptr)detailed);
	return texture;
}
