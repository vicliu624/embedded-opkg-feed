/* SPDX-License-Identifier: MIT */
#include <gperftools/tcmalloc.h>
#include <gperftools/heap-profiler.h>
#include <gperftools/profiler.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int main(int argc, char **argv)
{
 if (argc != 3) return 64;
 HeapProfilerStart(argv[1]);
 if (!IsHeapProfilerRunning()) return 1;
 unsigned char *allocation = tc_malloc(4096);
 if (!allocation) return 2;
 memset(allocation, 0x5a, 4096);
 allocation = tc_realloc(allocation, 8192);
 if (!allocation) return 3;
 for (int i = 0; i < 4096; i++) if (allocation[i] != 0x5a) return 4;
 HeapProfilerDump("tdvp-runtime-smoke");
 char *profile = GetHeapProfile();
 if (!profile || !strstr(profile, "heap profile:")) return 5;
 free(profile);
 tc_free(allocation);
 HeapProfilerStop();
 if (IsHeapProfilerRunning()) return 6;
 if (!ProfilerStart(argv[2])) return 7;
 volatile unsigned long value = 1;
 clock_t start = clock();
 while (clock() - start < CLOCKS_PER_SEC / 4)
  for (int i = 0; i < 10000; i++) value = value * 1664525UL + 1013904223UL;
 struct ProfilerState state;
 ProfilerGetCurrentState(&state);
 if (!state.enabled) return 8;
 ProfilerStop();
 if (!state.samples_gathered) {
  fprintf(stderr, "CPU profiler produced no samples under this execution environment\n");
  return 9;
 }
 printf("gperftools target: PASS allocation preservation, heap profile and %d CPU samples\n", state.samples_gathered);
 return 0;
}
