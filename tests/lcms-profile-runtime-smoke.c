/* SPDX-License-Identifier: MIT */
#include <lcms2.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
 cmsHPROFILE rgb = cmsCreate_sRGBProfile(), lab = cmsCreateLab4Profile(NULL);
 if (!rgb || !lab) return 1;
 cmsUInt32Number size = 0;
 if (!cmsSaveProfileToMem(rgb, NULL, &size) || size < 128) return 2;
 void *bytes = malloc(size);
 if (!bytes || !cmsSaveProfileToMem(rgb, bytes, &size)) return 3;
 cmsHPROFILE reopened = cmsOpenProfileFromMem(bytes, size);
 if (!reopened || cmsGetColorSpace(reopened) != cmsSigRgbData) return 4;
 cmsHPROFILE broken = cmsOpenProfileFromMem(bytes, 12);
 if (broken) return 5;
 cmsHTRANSFORM forward = cmsCreateTransform(reopened, TYPE_RGB_8, lab, TYPE_Lab_DBL,
                                          INTENT_RELATIVE_COLORIMETRIC, 0);
 cmsHTRANSFORM reverse = cmsCreateTransform(lab, TYPE_Lab_DBL, rgb, TYPE_RGB_8,
                                          INTENT_RELATIVE_COLORIMETRIC, 0);
 if (!forward || !reverse) return 6;
 unsigned char input[] = {0,0,0,255,255,255,255,0,0,0,255,0,0,0,255,64,128,192};
 unsigned char output[sizeof(input)];
 double converted[18];
 cmsDoTransform(forward, input, converted, 6);
 cmsDoTransform(reverse, converted, output, 6);
 for (unsigned i = 0; i < sizeof(input); i++)
  if (abs((int)input[i] - (int)output[i]) > 2) return 7;
 cmsDeleteTransform(reverse); cmsDeleteTransform(forward);
 cmsCloseProfile(reopened); cmsCloseProfile(lab); cmsCloseProfile(rgb); free(bytes);
 puts("Little CMS target: PASS ICC serialization, RGB/Lab roundtrip and truncated-profile rejection");
 return 0;
}
