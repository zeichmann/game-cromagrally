#include "game.h"
#include <math.h>


typedef struct
{
	short shoulder;
	short elbow;
	short wrist;
	OGLPoint3D grip[2];		// Brog and Grag, in wrist coordinates
} DriverArm;

static const DriverArm kRightArm = {2, 4, 5, {{-22, -10, -9}, {-22, -8, -18}}};
static const DriverArm kLeftArm  = {3, 6, 7, {{27, -8, -9}, {17, -8, -10}}};

enum
{
	DRIVER_TORSO = 0,
	DRIVER_HEAD = 1,
	DRIVER_RIGHT_LEG = 8,
	DRIVER_LEFT_LEG = 9,
};

enum
{
	CLUB_WHEEL,
	CLUB_GRAB,
	CLUB_CLEAR_RACK,
	CLUB_WINDUP,
	CLUB_DRIVE,
	CLUB_STRIKE,
	CLUB_FOLLOW_THROUGH,
	CLUB_RECOVER,
	CLUB_OVER_RACK,
	CLUB_STOW,
	CLUB_RETURN,
	NUM_CLUB_POSES,
};

typedef struct
{
	float time;
	OGLVector3D reach;
	float elbow;			// swivel about the shoulder-to-wrist line, in degrees
	OGLPoint3D torso;		// pitch, yaw, roll in degrees
	float tilt;				// shaft angle away from vertical
	float azimuth;			// shaft direction measured from the car's right side
	float glance;			// head turn away from the road
} ClubPose;

// Reach is relative to the right shoulder, in fractions of the arm's length.
static const ClubPose kClubPoses[NUM_CLUB_POSES] =
{
	[CLUB_WHEEL]          = {0.00f, {0},                     0, {  0,   0,   0},    12,  35,   0},
	[CLUB_GRAB]           = {0.19f, {0},                     6, {  1, -13,  -9},    12,  35, -17},
	[CLUB_CLEAR_RACK]     = {0.28f, {0},                   -55, {  3, -16,  -7},    12,  35, -21},
	[CLUB_WINDUP]         = {0.42f, {.64f,  .49f, -.14f},  -73, {  5,  -9,  -3},    39,  65, -20},
	[CLUB_DRIVE]          = {0.49f, {.78f,  .33f, -.26f},  -88, {  2, -17,  -6},    58,  32, -24},
	[CLUB_STRIKE]         = {0.57f, {.91f,  .13f, -.40f},  -53, { -7, -21, -17},   102, -11, -22},
	[CLUB_FOLLOW_THROUGH] = {0.66f, {.84f, -.17f, -.50f},  -26, {-11, -18, -18},   131, -21, -15},
	[CLUB_RECOVER]        = {0.82f, {.69f,  .17f, -.50f}, -128, { -4, -10, -10},    64, -18,  -4},
	[CLUB_OVER_RACK]      = {1.01f, {0},                   -63, {  1, -11,  -7},    12,  35,  -4},
	[CLUB_STOW]           = {1.11f, {0},                     6, {  1, -10,  -8},    12,  35,  -2},
	[CLUB_RETURN]         = {1.31f, {0},                     0, {  0,   0,   0},    12,  35,   0},
};

typedef struct
{
	int before, from, to, after;
	float t, span, beforeSpan, afterSpan;
} ClubInterval;

// Local to DriverClub.bg3d. The origin is inside the driver's palm.
static const OGLPoint3D kClubContact = {-4, 160, 0};
static const float kClubHeadRadius = 38;
static const float kClubFlinchDuration = .34f;

static const struct
{
	OGLPoint3D center;
	float radius;
} kDriverSkulls[] =
{
	{{-2, 27, -28}, 39},	// Brog
	{{-2, 36, -29}, 40},	// Grag (the ponytail lies outside this volume)
};

typedef struct
{
	uint32_t hitPlayers;
	OGLPoint3D previousContact;
	OGLPoint3D previousSkull;
	float hitStart, hitStop;
	float flinchTime, flinchSide;
	bool trackedSkull;
} PlayerClubData;

CheckSpecialDataStruct(PlayerClubData);


static OGLPoint3D GetRackGrip(const ObjNode* driver)
{
	static const OGLPoint3D stockMounts[] = {{87, 12, 54}, {77, 0, 51}};
	static const OGLPoint3D wickerMount = {84, 56, 40};
	const PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	const bool wicker = player->vehicleType == CAR_TYPE_WICKER;
	const OGLPoint3D* mount = wicker ? &wickerMount : &stockMounts[player->sex];
	const ObjNode* base = wicker ? player->objNode : driver;
	OGLPoint3D grip;
	OGLPoint3D_Transform(mount, &base->BaseTransformMatrix, &grip);
	return grip;
}


static OGLPoint3D GetTranslation(const OGLMatrix4x4* matrix)
{
	return (OGLPoint3D) {matrix->value[M03], matrix->value[M13], matrix->value[M23]};
}


static void SetTranslation(OGLMatrix4x4* matrix, OGLPoint3D point)
{
	matrix->value[M03] = point.x;
	matrix->value[M13] = point.y;
	matrix->value[M23] = point.z;
}


static ClubInterval FindClubInterval(float time)
{
	int from = CLUB_WHEEL;
	while (time >= kClubPoses[from+1].time)
		from++;
	const int to = from + 1;
	const int before = GAME_MAX(CLUB_WHEEL, from - 1);
	const int after = GAME_MIN(CLUB_RETURN, to + 1);
	const float span = kClubPoses[to].time - kClubPoses[from].time;
	return (ClubInterval)
	{
		.before = before, .from = from, .to = to, .after = after,
		.t = (time - kClubPoses[from].time) / span,
		.span = span,
		.beforeSpan = kClubPoses[from].time - kClubPoses[before].time,
		.afterSpan = kClubPoses[after].time - kClubPoses[to].time,
	};
}


static float ClubTangent(float incoming, float outgoing)
{
	// A component eases to a stop at a reversal. It flows through knots along the rest of the arc.
	return incoming * outgoing > 0 ? 2*incoming*outgoing / (incoming + outgoing) : 0;
}


static float SampleClubCurve(const ClubInterval* interval, float before, float from, float to, float after)
{
	const float speed = (to - from) / interval->span;
	const float start = interval->beforeSpan > 0 ? ClubTangent((from - before)/interval->beforeSpan, speed) : 0;
	const float end = interval->afterSpan > 0 ? ClubTangent(speed, (after - to)/interval->afterSpan) : 0;
	const float t = interval->t;
	const float u = 1 - t;
	return from + (to-from)*t*t*(3 - 2*t) + interval->span*t*u*(u*start - t*end);
}


static OGLPoint3D SampleClubPoint(const ClubInterval* interval, OGLPoint3D before, OGLPoint3D from, OGLPoint3D to, OGLPoint3D after)
{
	return (OGLPoint3D)
	{
		SampleClubCurve(interval, before.x, from.x, to.x, after.x),
		SampleClubCurve(interval, before.y, from.y, to.y, after.y),
		SampleClubCurve(interval, before.z, from.z, to.z, after.z),
	};
}


static OGLVector3D GetClubAxis(float tilt, float azimuth)
{
	const float radians = PI / 180.0f;
	const float side = sinf(tilt*radians);
	return (OGLVector3D) {side*cosf(azimuth*radians), cosf(tilt*radians), side*sinf(azimuth*radians)};
}


static OGLVector3D GetRackAxis(void)
{
	return GetClubAxis(kClubPoses[CLUB_GRAB].tilt, kClubPoses[CLUB_GRAB].azimuth);
}


static void SetDirectionRotation(OGLVector3D from, OGLVector3D to, OGLMatrix4x4* matrix)
{
	OGLVector3D_Normalize(&from, &from);
	OGLVector3D_Normalize(&to, &to);
	const float cosine = OGLVector3D_Dot(&from, &to);
	const float parallel = 1.0f - 1e-6f;
	if (cosine >= parallel)
	{
		OGLMatrix4x4_SetIdentity(matrix);
		return;
	}

	OGLVector3D axis;
	if (cosine <= -parallel)
	{
		const OGLVector3D reference = fabsf(from.y) < .8f ? (OGLVector3D){0, 1, 0} : (OGLVector3D){1, 0, 0};
		OGLVector3D_Cross(&from, &reference, &axis);
	}
	else
		OGLVector3D_Cross(&from, &to, &axis);
	OGLMatrix4x4_SetRotateAboutAxis(matrix, &axis, acosf(cosine));
}


static OGLMatrix4x4 MakeClubFrame(const ObjNode* car, OGLVector3D localAxis)
{
	const OGLVector3D up = {0, 1, 0};
	OGLMatrix4x4 rotation, frame;
	SetDirectionRotation(up, localAxis, &rotation);
	OGLMatrix4x4_Multiply(&rotation, &car->BaseTransformMatrix, &frame);
	return frame;
}


static void PlaceClubPiece(ObjNode* piece, const OGLMatrix4x4* frame, OGLPoint3D grip)
{
	piece->BaseTransformMatrix = *frame;
	SetTranslation(&piece->BaseTransformMatrix, grip);
	piece->Coord = grip;
	SetObjectTransformMatrix(piece);
}


static void AimArmJoint(OGLMatrix4x4* matrix, OGLPoint3D pivot, OGLVector3D from, OGLVector3D to)
{
	OGLMatrix4x4 rotation;
	SetDirectionRotation(from, to, &rotation);
	OGLMatrix4x4_Multiply(matrix, &rotation, matrix);
	SetTranslation(matrix, pivot);
}


static OGLVector3D ProjectPerpendicular(OGLVector3D vector, OGLVector3D axis)
{
	// OGLVector3D_Dot clamps to [-1, 1] for angles. This projection uses lengths.
	const float along = vector.x*axis.x + vector.y*axis.y + vector.z*axis.z;
	return (OGLVector3D) {vector.x - along*axis.x, vector.y - along*axis.y, vector.z - along*axis.z};
}


static OGLVector3D PerpendicularDirection(OGLVector3D vector, OGLVector3D axis)
{
	OGLVector3D perpendicular = ProjectPerpendicular(vector, axis);
	if (CalcVectorLength(&perpendicular) < .001f)
	{
		const OGLVector3D pole = fabsf(axis.y) < .8f ? (OGLVector3D){0, -1, 0} : (OGLVector3D){0, 0, -1};
		perpendicular = ProjectPerpendicular(pole, axis);
	}
	OGLVector3D_Normalize(&perpendicular, &perpendicular);
	return perpendicular;
}


static OGLPoint3D SolveElbow(OGLPoint3D shoulder, OGLPoint3D* wrist, OGLVector3D pole,
							const OGLVector3D* carRight, float upperLength, float lowerLength)
{
	OGLVector3D direction;
	OGLPoint3D_Subtract(wrist, &shoulder, &direction);
	const float distance = CalcVectorLength(&direction);
	const float reach = SDL_clamp(distance,
								  fabsf(upperLength-lowerLength) + .1f, upperLength+lowerLength-.1f);
	if (distance < EPS)
		direction = (OGLVector3D){1, 0, 0};
	else
		OGLVector3D_Normalize(&direction, &direction);
	OGLVector3D bend;
	if (carRight)
	{
		// Transport the bend around the arm's axis. Projecting a fixed elbow guide would flip
		// the elbow when the hand passes through the guide.
		OGLMatrix4x4 move;
		SetDirectionRotation(*carRight, direction, &move);
		OGLVector3D_Transform(&pole, &move, &bend);
	}
	else
		bend = PerpendicularDirection(pole, direction);
	const float along = (reach*reach + upperLength*upperLength - lowerLength*lowerLength) / (2*reach);
	const float height = sqrtf(fmaxf(0, upperLength*upperLength - along*along));

	*wrist = (OGLPoint3D){shoulder.x + direction.x*reach, shoulder.y + direction.y*reach, shoulder.z + direction.z*reach};
	return (OGLPoint3D)
	{
		shoulder.x + direction.x*along + bend.x*height,
		shoulder.y + direction.y*along + bend.y*height,
		shoulder.z + direction.z*along + bend.z*height,
	};
}


static OGLPoint3D WristForGrip(const OGLMatrix4x4* hand, const OGLPoint3D* localGrip, OGLPoint3D target)
{
	const OGLPoint3D wrist = GetTranslation(hand);
	OGLPoint3D grip;
	OGLPoint3D_Transform(localGrip, hand, &grip);
	return (OGLPoint3D){target.x + (wrist.x-grip.x), target.y + (wrist.y-grip.y), target.z + (wrist.z-grip.z)};
}


static void TurnHandToClub(OGLMatrix4x4* hand, OGLVector3D gripAcross, OGLVector3D forearm, float forearmPitch, float blend)
{
	if (blend == 0)
		return;

	const float scale = sqrtf(hand->value[M00]*hand->value[M00]
		+ hand->value[M10]*hand->value[M10] + hand->value[M20]*hand->value[M20]);
	OGLVector3D_Normalize(&gripAcross, &gripAcross);
	OGLVector3D_Normalize(&forearm, &forearm);
	if (blend < 1)
	{
		OGLVector3D freeAcross = {hand->value[M00], hand->value[M10], hand->value[M20]};
		OGLVector3D_Normalize(&freeAcross, &freeAcross);
		const OGLVector3D freeUp = {hand->value[M01], hand->value[M11], hand->value[M21]};
		const OGLVector3D freeBack = {hand->value[M02], hand->value[M12], hand->value[M22]};
		const float freePitch = atan2f(OGLVector3D_Dot(&forearm, &freeUp), OGLVector3D_Dot(&forearm, &freeBack));
		forearmPitch = freePitch + blend*(forearmPitch-freePitch);
		const float freeBend = acosf(OGLVector3D_Dot(&freeAcross, &forearm));
		const float clubBend = acosf(OGLVector3D_Dot(&gripAcross, &forearm));
		const float bend = freeBend + blend*(clubBend-freeBend);

		// Open and close the grip by turning about the forearm, keeping wrist flex separate.
		const OGLVector3D from = PerpendicularDirection(freeAcross, forearm);
		const OGLVector3D to = PerpendicularDirection(gripAcross, forearm);
		OGLVector3D tangent;
		OGLVector3D_Cross(&forearm, &from, &tangent);
		const float twist = blend * atan2f(OGLVector3D_Dot(&tangent, &to), OGLVector3D_Dot(&from, &to));
		const float c = cosf(twist)*sinf(bend);
		const float s = sinf(twist)*sinf(bend);
		const float along = cosf(bend);
		gripAcross = (OGLVector3D)
		{
			along*forearm.x + c*from.x + s*tangent.x,
			along*forearm.y + c*from.y + s*tangent.y,
			along*forearm.z + c*from.z + s*tangent.z,
		};
	}

	// The shaft runs across the closed fist. Align the back of the hand with
	// the forearm in the plane perpendicular to the shaft.
	const OGLVector3D projected = PerpendicularDirection(forearm, gripAcross);
	OGLVector3D tangent;
	OGLVector3D_Cross(&gripAcross, &projected, &tangent);
	const float c = cosf(forearmPitch);
	const float s = sinf(forearmPitch);
	const OGLVector3D gripBack =
	{
		c*projected.x + s*tangent.x,
		c*projected.y + s*tangent.y,
		c*projected.z + s*tangent.z,
	};

	OGLVector3D up;
	OGLVector3D_Cross(&gripBack, &gripAcross, &up);
	hand->value[M00] = scale*gripAcross.x;
	hand->value[M10] = scale*gripAcross.y;
	hand->value[M20] = scale*gripAcross.z;
	hand->value[M01] = scale*up.x;
	hand->value[M11] = scale*up.y;
	hand->value[M21] = scale*up.z;
	hand->value[M02] = scale*gripBack.x;
	hand->value[M12] = scale*gripBack.y;
	hand->value[M22] = scale*gripBack.z;
}


static float SampleElbowAngle(const ClubInterval* interval, float seated)
{
	const float before = interval->before == CLUB_WHEEL ? seated : kClubPoses[interval->before].elbow;
	const float from = interval->from == CLUB_WHEEL ? seated : kClubPoses[interval->from].elbow;
	const float to = interval->to == CLUB_RETURN ? seated : kClubPoses[interval->to].elbow;
	const float after = interval->after == CLUB_RETURN ? seated : kClubPoses[interval->after].elbow;
	return SampleClubCurve(interval, before, from, to, after);
}


static OGLPoint3D PoseDriverArm(ObjNode* driver, const DriverArm* arm, const OGLPoint3D* localGrip,
								OGLPoint3D target, OGLMatrix4x4 hand, const OGLMatrix4x4* shaft,
								const ClubInterval* swing, float gripBlend)
{
	OGLMatrix4x4 shoulderMatrix, elbowMatrix;
	OGLPoint3D wrist;
	FindJointFullMatrix(driver, arm->shoulder, &shoulderMatrix);
	FindJointFullMatrix(driver, arm->elbow, &elbowMatrix);
	FindCoordOfJoint(driver, arm->wrist, &wrist);
	const OGLPoint3D shoulder = GetTranslation(&shoulderMatrix);
	const OGLPoint3D elbow = GetTranslation(&elbowMatrix);
	OGLVector3D upper, lower;
	OGLPoint3D_Subtract(&elbow, &shoulder, &upper);
	OGLPoint3D_Subtract(&wrist, &elbow, &lower);
	const float upperLength = CalcVectorLength(&upper);
	const float lowerLength = CalcVectorLength(&lower);

	OGLVector3D pole = upper;
	OGLVector3D carRight;
	const OGLVector3D* bendAxis = NULL;
	OGLPoint3D newWrist = WristForGrip(&hand, localGrip, target);
	if (swing)
	{
		const OGLVector3D right = {1, 0, 0};
		const OGLVector3D down = {0, -1, 0};
		const OGLVector3D forward = {0, 0, -1};
		OGLVector3D_Transform(&right, &driver->BaseTransformMatrix, &carRight);
		bendAxis = &carRight;

		OGLVector3D armAxis;
		OGLPoint3D_Subtract(&wrist, &shoulder, &armAxis);
		OGLMatrix4x4 seatedBend, frame;
		SetDirectionRotation(carRight, armAxis, &seatedBend);
		OGLMatrix4x4_Multiply(&driver->BaseTransformMatrix, &seatedBend, &frame);
		OGLVector3D seatedDown, seatedForward;
		OGLVector3D_Transform(&down, &frame, &seatedDown);
		OGLVector3D_Transform(&forward, &frame, &seatedForward);
		OGLVector3D_Normalize(&upper, &pole);
		const float radians = PI/180;
		const float seatedAngle = atan2f(OGLVector3D_Dot(&pole, &seatedForward), OGLVector3D_Dot(&pole, &seatedDown)) / radians;
		const float elbowAngle = SampleElbowAngle(swing, seatedAngle) * radians;
		const OGLVector3D localBend = {0, -cosf(elbowAngle), -sinf(elbowAngle)};
		OGLVector3D_Transform(&localBend, &driver->BaseTransformMatrix, &pole);

		const OGLVector3D downShaft = {0, -1, 0};
		OGLVector3D across;
		OGLVector3D_Transform(&downShaft, shaft, &across);
		static const float forearmPitch[] = {26 * PI/180, 10 * PI/180}; // Brog and Grag's rest poses
		const float pitch = forearmPitch[gPlayerInfo[driver->PlayerNum].sex];
		OGLMatrix4x4 wheelHand;
		FindJointFullMatrix(driver, arm->wrist, &wheelHand);
		newWrist = WristForGrip(&wheelHand, localGrip, target);
		const float alongShaft = driver->Scale.x * localGrip->x;
		newWrist.x += gripBlend*(target.x - across.x*alongShaft - newWrist.x);
		newWrist.y += gripBlend*(target.y - across.y*alongShaft - newWrist.y);
		newWrist.z += gripBlend*(target.z - across.z*alongShaft - newWrist.z);
		// Account for the distance from the wrist joint to the palm as the grip turns.
		for (int i = 0; i < 3; i++)
		{
			OGLPoint3D estimate = newWrist;
			const OGLPoint3D bend = SolveElbow(shoulder, &estimate, pole, bendAxis, upperLength, lowerLength);
			OGLVector3D forearm;
			OGLPoint3D_Subtract(&bend, &estimate, &forearm);
			hand = wheelHand;
			if (gripBlend < 1)
			{
				// During the reach, turn the relaxed hand with the forearm before closing the grip.
				const OGLVector3D towardWrist = {-forearm.x, -forearm.y, -forearm.z};
				AimArmJoint(&hand, estimate, lower, towardWrist);
			}
			TurnHandToClub(&hand, across, forearm, pitch, gripBlend);
			newWrist = WristForGrip(&hand, localGrip, target);
		}
	}

	// Fit the wrist to the oriented grip. The hand stays connected to the forearm.
	const OGLPoint3D newElbow = SolveElbow(shoulder, &newWrist, pole, bendAxis, upperLength, lowerLength);
	OGLVector3D aimedUpper, aimedLower;
	OGLPoint3D_Subtract(&newElbow, &shoulder, &aimedUpper);
	OGLPoint3D_Subtract(&newWrist, &newElbow, &aimedLower);

	AimArmJoint(&shoulderMatrix, shoulder, upper, aimedUpper);
	AimArmJoint(&elbowMatrix, newElbow, lower, aimedLower);
	SetTranslation(&hand, newWrist);

	SkeletonObjDataType* skeleton = driver->Skeleton;
	const short parent = skeleton->skeletonDefinition->Bones[arm->shoulder].parentBone;
	OGLMatrix4x4 parentMatrix, inverse;
	FindJointFullMatrix(driver, parent, &parentMatrix);
	OGLMatrix4x4_Invert(&parentMatrix, &inverse);
	OGLMatrix4x4_Multiply(&shoulderMatrix, &inverse, &skeleton->jointTransformMatrix[arm->shoulder]);
	OGLMatrix4x4_Invert(&shoulderMatrix, &inverse);
	OGLMatrix4x4_Multiply(&elbowMatrix, &inverse, &skeleton->jointTransformMatrix[arm->elbow]);
	OGLMatrix4x4_Invert(&elbowMatrix, &inverse);
	OGLMatrix4x4_Multiply(&hand, &inverse, &skeleton->jointTransformMatrix[arm->wrist]);

	OGLPoint3D grip;
	OGLPoint3D_Transform(localGrip, &hand, &grip);
	return grip;
}


static void MakeClubHitSparks(OGLPoint3D position, const OGLVector3D* carVelocity)
{
	NewParticleGroupDefType group =
	{
		.type = PARTICLE_TYPE_FALLINGSPARKS,
		.flags = PARTICLE_FLAGS_DONTCHECKGROUND,
		.gravity = 480,
		.baseScale = 15,
		.fadeRate = 2.9f,
		.particleTextureNum = PARTICLE_SObjType_WhiteSpark,
		.srcBlend = GL_SRC_ALPHA,
		.dstBlend = GL_ONE,
	};
	const short groupNum = NewParticleGroup(&group);
	if (groupNum < 0)
		return;

	position.y += 17;
	for (int i = 0; i < 6; i++)
	{
		const float angle = i*PI2/6.0f;
		OGLVector3D velocity = {carVelocity->x + 142*cosf(angle), 155 + 52*(i%2),
							   carVelocity->z + 142*sinf(angle)};
		NewParticleDefType spark =
		{
			.groupNum = groupNum,
			.where = &position,
			.delta = &velocity,
			.scale = i%2 ? 1.0f : 1.3f,
			.rotZ = angle,
			.rotDZ = i%2 ? 4.5f : -4.5f,
			.alpha = 1,
		};
		AddParticleToGroup(&spark);
	}
}


static void RotateJoint(OGLMatrix4x4* joint, OGLPoint3D angles)
{
	const float radians = PI / 180.0f;
	const OGLPoint3D pivot = GetTranslation(joint);
	OGLMatrix4x4 lean;
	OGLMatrix4x4_SetRotate_XYZ(&lean, angles.x*radians, angles.y*radians, angles.z*radians);
	OGLMatrix4x4_Multiply(joint, &lean, joint);
	SetTranslation(joint, pivot);
}


static void LeanDriver(ObjNode* driver, OGLPoint3D angles, float glance)
{
	OGLMatrix4x4* joints = driver->Skeleton->jointTransformMatrix;
	const OGLMatrix4x4 seated = joints[DRIVER_TORSO];
	RotateJoint(&joints[DRIVER_TORSO], angles);
	RotateJoint(&joints[DRIVER_HEAD], (OGLPoint3D){0, glance, 0});

	// The legs are children of the torso bone. Keep them planted in the footwell.
	OGLMatrix4x4 inverse, correction;
	OGLMatrix4x4_Invert(&joints[DRIVER_TORSO], &inverse);
	OGLMatrix4x4_Multiply(&seated, &inverse, &correction);
	OGLMatrix4x4_Multiply(&joints[DRIVER_RIGHT_LEG], &correction, &joints[DRIVER_RIGHT_LEG]);
	OGLMatrix4x4_Multiply(&joints[DRIVER_LEFT_LEG], &correction, &joints[DRIVER_LEFT_LEG]);
}

typedef struct
{
	ObjNode* club;
	PlayerClubData* data;
	OGLPoint3D oldSkull, skull;
	float radius;
} ClubPlayerPose;


static bool ClubPathHitsHead(const PlayerClubData* swing, OGLPoint3D clubEnd, const ClubPlayerPose* target, float clubRadius)
{
	// Sweep relative to the other driver's head, including both players' motion.
	OGLVector3D start, end;
	OGLPoint3D_Subtract(&swing->previousContact, &target->oldSkull, &start);
	OGLPoint3D_Subtract(&clubEnd, &target->skull, &end);
	const OGLVector3D travel = {end.x-start.x, end.y-start.y, end.z-start.z};
	const float distanceSquared = SQUARED(travel.x) + SQUARED(travel.y) + SQUARED(travel.z);
	const float approach = -(start.x*travel.x + start.y*travel.y + start.z*travel.z);
	const float closest = distanceSquared > EPS ? approach/distanceSquared : swing->hitStart;
	const float t = SDL_clamp(closest, swing->hitStart, swing->hitStop);
	const OGLVector3D separation = {start.x+t*travel.x, start.y+t*travel.y, start.z+t*travel.z};
	const float radius = clubRadius + target->radius;
	return SQUARED(separation.x) + SQUARED(separation.y) + SQUARED(separation.z) <= radius*radius;
}


void ResolvePlayerClubHits(void)
{
	ClubPlayerPose poses[MAX_PLAYERS] = {0};
	for (int i = 0; i < gNumTotalPlayers; i++)
	{
		const PlayerInfoType* player = &gPlayerInfo[i];
		ObjNode* driver = player->headObj;
		if (!IsLandCarType(player->vehicleType) || !player->objNode || player->isEliminated
			|| player->objNode->CType == INVALID_NODE_FLAG || !driver || driver->CType == INVALID_NODE_FLAG
			|| !driver->Skeleton || !driver->ChainNode || !driver->ChainNode->ChainNode)
			continue;

		ClubPlayerPose* pose = &poses[i];
		pose->club = driver->ChainNode->ChainNode;
		PlayerClubData* data = GetSpecialData(pose->club, PlayerClubData);
		pose->data = data;
		if (data->flinchTime > 0)
		{
			const float amount = data->flinchTime/kClubFlinchDuration;
			RotateJoint(&driver->Skeleton->jointTransformMatrix[DRIVER_HEAD],
				(OGLPoint3D){-15*amount, -10*amount*data->flinchSide, -23*amount*data->flinchSide});
			data->flinchTime -= gFramesPerSecondFrac;
		}

		const int sex = player->sex;
		FindCoordOnJoint(driver, DRIVER_HEAD, &kDriverSkulls[sex].center, &pose->skull);
		pose->oldSkull = data->trackedSkull ? data->previousSkull : pose->skull;
		pose->radius = kDriverSkulls[sex].radius * driver->Scale.x;
		data->previousSkull = pose->skull;
		data->trackedSkull = true;
	}

	for (int i = 0; i < gNumTotalPlayers; i++)
	{
		const ClubPlayerPose* attack = &poses[i];
		PlayerClubData* data = attack->data;
		if (!data || data->hitStop <= data->hitStart)
			continue;

		const ObjNode* car = gPlayerInfo[i].objNode;
		const float rightX = cosf(car->Rot.y), rightZ = -sinf(car->Rot.y);
		const float radius = kClubHeadRadius * car->Scale.x;
		OGLPoint3D contact;
		OGLPoint3D_Transform(&kClubContact, &attack->club->BaseTransformMatrix, &contact);
		for (int j = 0; j < gNumTotalPlayers; j++)
		{
			const ClubPlayerPose* other = &poses[j];
			if (i == j || !other->data || (data->hitPlayers & (1u << j)))
				continue;
			const float side = (other->skull.x-car->Coord.x)*rightX + (other->skull.z-car->Coord.z)*rightZ;
			if (side <= 0 || !ClubPathHitsHead(data, contact, other, radius))
				continue;

			data->hitPlayers |= 1u << j;
			PlayerInfoType* rival = &gPlayerInfo[j];
			ObjNode* target = rival->objNode;
			MakeClubHitSparks(other->skull, &target->Delta);
			PlayEffect_Parms3D(EFFECT_CRASH2, &other->skull, NORMAL_CHANNEL_RATE, .8f);
			target->Delta.x += 625.0f * rightX;
			target->Delta.z += 625.0f * rightZ;
			target->DeltaRot.y += 2.4f;
			rival->greasedTiresTimer = fmaxf(rival->greasedTiresTimer, .40f);
			rival->isPlaning = true;
			other->data->flinchTime = kClubFlinchDuration;
			other->data->flinchSide = rightX*cosf(target->Rot.y)-rightZ*sinf(target->Rot.y) >= 0 ? 1 : -1;
		}
		data->hitStop = 0;
	}
}


void CreatePlayerClub(ObjNode* driver)
{
	NewObjectDefinitionType def =
	{
		.group = MODEL_GROUP_DRIVER_CLUB,
		.type = DRIVER_CLUB_ObjType_Rack,
		.slot = driver->Slot,
		.scale = 1,
		.player = driver->PlayerNum,
	};
	ObjNode* rack = MakeNewDisplayGroupObject(&def);
	GAME_ASSERT(rack);

	def.type = DRIVER_CLUB_ObjType_Club;
	ObjNode* club = MakeNewDisplayGroupObject(&def);
	GAME_ASSERT(club);

	driver->ChainNode = rack;
	rack->ChainNode = club;
	PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	player->clubSwingTime = 0;

	const OGLPoint3D stowed = GetRackGrip(driver);
	const OGLMatrix4x4 rackFrame = MakeClubFrame(player->objNode, GetRackAxis());
	PlaceClubPiece(rack, &rackFrame, stowed);
	PlaceClubPiece(club, &rackFrame, stowed);
}


void UpdatePlayerClub(ObjNode* driver)
{
	PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	ObjNode* rack = driver->ChainNode;
	ObjNode* club = rack->ChainNode;
	PlayerClubData* data = GetSpecialData(club, PlayerClubData);
	data->hitStop = 0;
	const ObjNode* car = player->objNode;
	const OGLPoint3D stowed = GetRackGrip(driver);
	const OGLMatrix4x4 rackFrame = MakeClubFrame(car, GetRackAxis());
	PlaceClubPiece(rack, &rackFrame, stowed);

	const int anim = driver->Skeleton->AnimNum;
	const bool canSwing = !gNoCarControls && !player->isEliminated && !player->raceComplete
		&& player->frozenTimer <= 0 && anim != PLAYER_ANIM_THROWFORWARD && anim != PLAYER_ANIM_THROWBACKWARD;
	const float previousTime = player->clubSwingTime;
	const float time = previousTime + gFramesPerSecondFrac;
	if (!canSwing || time >= kClubPoses[CLUB_RETURN].time
		|| (previousTime == 0 && !GetControlStateNew(driver->PlayerNum, kControlBit_ClubSwing)))
	{
		player->clubSwingTime = 0;
		PlaceClubPiece(club, &rackFrame, stowed);
		return;
	}

	player->clubSwingTime = time;
	if (previousTime == 0)
		data->hitPlayers = 0;

	const ClubInterval interval = FindClubInterval(time);
	const ClubPose* before = &kClubPoses[interval.before];
	const ClubPose* from = &kClubPoses[interval.from];
	const ClubPose* to = &kClubPoses[interval.to];
	const ClubPose* after = &kClubPoses[interval.after];
	const float tilt = SampleClubCurve(&interval, before->tilt, from->tilt, to->tilt, after->tilt);
	const float azimuth = SampleClubCurve(&interval, before->azimuth, from->azimuth, to->azimuth, after->azimuth);
	const OGLMatrix4x4 clubFrame = MakeClubFrame(car, GetClubAxis(tilt, azimuth));

	const OGLPoint3D* rightGrip = &kRightArm.grip[player->sex];
	const OGLPoint3D* leftGrip = &kLeftArm.grip[player->sex];
	OGLMatrix4x4 rightHand, leftHand;
	OGLPoint3D rightWheelGrip, leftWheelGrip;
	FindJointFullMatrix(driver, kRightArm.wrist, &rightHand);
	FindJointFullMatrix(driver, kLeftArm.wrist, &leftHand);
	OGLPoint3D_Transform(rightGrip, &rightHand, &rightWheelGrip);
	OGLPoint3D_Transform(leftGrip, &leftHand, &leftWheelGrip);

	const float glance = SampleClubCurve(&interval, before->glance, from->glance, to->glance, after->glance);
	LeanDriver(driver, SampleClubPoint(&interval, before->torso, from->torso, to->torso, after->torso), glance);
	PoseDriverArm(driver, &kLeftArm, leftGrip, leftWheelGrip, leftHand, NULL, NULL, 0);

	OGLPoint3D shoulder;
	FindCoordOfJoint(driver, kRightArm.shoulder, &shoulder);
	const BoneDefinitionType* bones = driver->Skeleton->skeletonDefinition->Bones;
	const float armLength = driver->Scale.x * (OGLPoint3D_Distance(&bones[kRightArm.shoulder].coord, &bones[kRightArm.elbow].coord)
		+ OGLPoint3D_Distance(&bones[kRightArm.elbow].coord, &bones[kRightArm.wrist].coord));
	const OGLPoint3D liftFromRack = {0, 24, 0};
	OGLPoint3D overRack;
	OGLPoint3D_Transform(&liftFromRack, &rack->BaseTransformMatrix, &overRack);
	OGLPoint3D grips[NUM_CLUB_POSES] =
	{
		[CLUB_WHEEL] = rightWheelGrip, [CLUB_GRAB] = stowed,
		[CLUB_CLEAR_RACK] = overRack, [CLUB_OVER_RACK] = overRack,
		[CLUB_STOW] = stowed, [CLUB_RETURN] = rightWheelGrip,
	};
	for (int i = CLUB_WINDUP; i <= CLUB_RECOVER; i++)
	{
		OGLVector3D reach = kClubPoses[i].reach;
		OGLVector3D reachDirection;
		OGLVector3D_Transform(&reach, &driver->BaseTransformMatrix, &reachDirection);
		const float length = armLength * CalcVectorLength(&reach);
		grips[i] = (OGLPoint3D){shoulder.x + length*reachDirection.x,
							   shoulder.y + length*reachDirection.y,
							   shoulder.z + length*reachDirection.z};
	}

	OGLPoint3D targetGrip = SampleClubPoint(&interval,
			grips[interval.before], grips[interval.from], grips[interval.to], grips[interval.after]);
	const float grasp = interval.from == CLUB_WHEEL ? interval.t : interval.from == CLUB_STOW ? 1-interval.t : 1;
	const float closeGrip = SDL_clamp((grasp - .15f)/.85f, 0, 1);
	const float gripBlend = closeGrip*closeGrip*(3 - 2*closeGrip);
	// Take the hand out around the driver's side between the wheel and the rack.
	const float reachArc = 16*grasp*grasp*(1-grasp)*(1-grasp);
	OGLVector3D clearance = {.30f, .175f, 0};
	OGLVector3D aroundRim;
	OGLVector3D_Transform(&clearance, &car->BaseTransformMatrix, &aroundRim);
	const float arcDistance = armLength * CalcVectorLength(&clearance) * reachArc;
	targetGrip.x += aroundRim.x*arcDistance;
	targetGrip.y += aroundRim.y*arcDistance;
	targetGrip.z += aroundRim.z*arcDistance;
	const OGLPoint3D heldGrip = PoseDriverArm(driver, &kRightArm, rightGrip, targetGrip, rightHand,
											&clubFrame, &interval, gripBlend);

	OGLPoint3D_Transform(&kClubContact, &club->BaseTransformMatrix, &data->previousContact);
	if (interval.from >= CLUB_GRAB && interval.from < CLUB_STOW)
		PlaceClubPiece(club, &clubFrame, heldGrip);
	else
		PlaceClubPiece(club, &rackFrame, stowed);

	const float hitStart = kClubPoses[CLUB_DRIVE].time;
	const float hitEnd = kClubPoses[CLUB_FOLLOW_THROUGH].time;
	if (previousTime < hitStart && time >= hitStart)
		PlayEffect_Parms3D(EFFECT_THROW1, &club->Coord, NORMAL_CHANNEL_RATE, .7f);
	if (time > hitStart && previousTime < hitEnd)
	{
		const float dt = time - previousTime;
		data->hitStart = fmaxf(0, (hitStart-previousTime)/dt);
		data->hitStop = fminf(1, (hitEnd-previousTime)/dt);
	}
}
