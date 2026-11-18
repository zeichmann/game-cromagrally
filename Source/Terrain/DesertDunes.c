#include "game.h"
#include <math.h>

typedef struct
{
	float x, z;
	float angle;
	float halfLength;
	float windward, leeward;
	float height;
	float bend;
} DesertDune;

// Crest center, angle in degrees, half length, runs on each side, height, and bend.
static const DesertDune kDesertDunes[] =
{
	// Starting straight and first turns.
	{77220, 89570,   7, 2060, 1060,  940, 330, 320},
	{75150, 85690,  -2, 1870, 1110,  970, 345, 340},
	{81680, 86900, -61, 1980, 1340, 1040, 320, 340},
	{82840, 80180, -79, 2310, 1160, 1090, 315, 310},
	{84750, 76400, -49, 2350, 1230, 1090, 350, 370},

	// Eastern flats.
	{115920, 79050,  10, 2600, 1500, 1290, 490, 440},
	{121430, 78600, -25, 2990, 1640, 1350, 570, 460},
	{125270, 75360, -44, 2450, 1550, 1200, 425, 350},
	{128090, 72760, -49, 2770, 1640, 1450, 560, 480},
	{130760, 69510, -58, 2440, 1440, 1260, 475, 420},

	// Northern basin.
	{122950, 23580,   9, 2850, 1600, 1550, 635, 480},
	{117920, 23860,  -4, 2350, 1440, 1260, 480, 420},
	{116060, 30780,  27, 2610, 1450, 1320, 505, 460},
	{112570, 32460,  35, 2380, 1450, 1250, 450, 370},
	{109770, 27350,  20, 2300, 1420, 1140, 415, 380},

	// Western flats.
	{19070, 52180, 115, 2160, 1400, 1190, 480, 350},
	{18330, 56680, 102, 2720, 1660, 1420, 554, 475},
	{22450, 65235, 106, 3080, 1780, 1600, 660, 530},
	{15830, 68000, 105, 2600, 1520, 1400, 530, 400},
	{19700, 73380, 117, 2720, 1630, 1410, 580, 420},
	{13030, 74800, 107, 2450, 1490, 1310, 470, 430},
	{16850, 80500,  99, 2650, 1630, 1400, 540, 455},

	// Return leg.
	{25800,  94330, -10, 2560, 1200, 1260, 430, 360},
	{30280,  93650,  -2, 2270, 1190, 1200, 360, 290},
	{53000, 105440, -21, 2550, 1520, 1220, 470, 370},
	{56600, 101710, -50, 2550, 1480, 1240, 452, 385},
};

float DesertDuneHeight(float x, float z)
{
	float height = 0;
	for (int i = 0; i < SDL_arraysize(kDesertDunes); i++)
	{
		const DesertDune* dune = &kDesertDunes[i];
		const float dx = x-dune->x, dz = z-dune->z;
		const float maximumRun = fmaxf(dune->windward, dune->leeward) + dune->bend;
		if (dx*dx + dz*dz >= SQUARED(dune->halfLength) + SQUARED(maximumRun))
			continue;

		const float angle = dune->angle * (PI/180.0f);
		const float c = cosf(angle), s = sinf(angle);
		const float along = (dx*c + dz*s)/dune->halfLength;
		const float taper = 1.0f - along*along;
		if (taper <= 0)
			continue;

		// Bend the ridge into a crescent with a long windward face and a shorter lee.
		const float across = -dx*s + dz*c - dune->bend*along*along;
		const float run = (across < 0 ? dune->windward : dune->leeward) * (.62f + .38f*taper);
		const float f = fabsf(across)/run;
		if (f < 1)
			height = fmaxf(height, dune->height * taper*taper * (1 - f*f*(3 - 2*f)));
	}
	return height;
}

void ApplyDesertDunes(void)
{
	// The renderer, car suspension, and particle collision all read this grid.
	for (int row = 1; row < gTerrainTileDepth; row++)
	{
		for (int col = 1; col < gTerrainTileWidth; col++)
		{
			const float lift = DesertDuneHeight(col*TERRAIN_POLYGON_SIZE, row*TERRAIN_POLYGON_SIZE);
			gMapYCoords[row][col] += lift * gUserPhysics.terrainHeight;
		}
	}
}
