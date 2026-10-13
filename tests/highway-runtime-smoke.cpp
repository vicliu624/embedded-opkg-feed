/* SPDX-License-Identifier: MIT */
#include <hwy/highway.h>
#include <hwy/aligned_allocator.h>
#include <hwy/contrib/sort/vqsort.h>
#include <cstdio>

int main()
{
 const hwy::HWY_NAMESPACE::ScalableTag<float> tag;
 const size_t lanes = hwy::HWY_NAMESPACE::Lanes(tag);
 auto values = hwy::AllocateAligned<float>(64);
 if (!values || !lanes || lanes > 64 || 64 % lanes) return 1;
 for (size_t i = 0; i < 64; i++) values[i] = static_cast<float>(i);
 for (size_t i = 0; i < 64; i += lanes) {
  const auto v = hwy::HWY_NAMESPACE::LoadU(tag, values.get() + i);
  hwy::HWY_NAMESPACE::StoreU(hwy::HWY_NAMESPACE::Add(v, v), tag, values.get() + i);
 }
 for (size_t i = 0; i < 64; i++) if (values[i] != 2.0f * i) return 2;
 uint64_t keys[] = {9,1,5,0,8,2,7,3,6,4};
 hwy::VQSort(keys, 10, hwy::SortAscending{});
 for (size_t i = 0; i < 10; i++) if (keys[i] != i) return 3;
 std::puts("Highway CPU0 target: PASS aligned allocation, vector API arithmetic and contrib sort");
 return 0;
}
